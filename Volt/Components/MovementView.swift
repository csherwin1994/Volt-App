import SwiftUI

// Volt Motion for iOS: the line-drawn exercise animations.
//
// Same data and the same rules as the web engine (design/motion/volt-motion.js), so a movement looks
// identical on the prototype and the phone. The data is Resources/movements.json, copied from
// design/movements.json by design/generate_theme.py.
//
// World units are metres, y is up, the floor is y = 0, the figure faces +x.
// Limb angles: degrees from straight down, + towards +x. Torso and head: degrees from straight up.

/// A point in world space (metres). Kept separate from CGPoint so the maths stays in Double.
struct MP {
    var x: Double
    var y: Double
    static let zero = MP(x: 0, y: 0)
}

// MARK: - Loose JSON value (poses are interpolated field by field)

indirect enum MotionValue: Decodable {
    case num(Double), str(String), bool(Bool), arr([MotionValue]), obj([String: MotionValue]), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let d = try? c.decode(Double.self) { self = .num(d) }
        else if let s = try? c.decode(String.self) { self = .str(s) }
        else if let a = try? c.decode([MotionValue].self) { self = .arr(a) }
        else { self = .obj(try c.decode([String: MotionValue].self)) }
    }

    subscript(key: String) -> MotionValue? {
        if case .obj(let o) = self { return o[key] }
        return nil
    }
    var double: Double? { if case .num(let d) = self { return d }; return nil }
    var string: String? { if case .str(let s) = self { return s }; return nil }
    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var array: [MotionValue]? { if case .arr(let a) = self { return a }; return nil }
    var object: [String: MotionValue]? { if case .obj(let o) = self { return o }; return nil }
    var point: MP? {
        guard let a = array, a.count == 2, let x = a[0].double, let y = a[1].double else { return nil }
        return MP(x: x, y: y)
    }

    static func lerp(_ a: MotionValue, _ b: MotionValue, _ t: Double) -> MotionValue {
        switch (a, b) {
        case let (.num(x), .num(y)):
            return .num(x + (y - x) * t)
        case let (.arr(x), .arr(y)) where x.count == y.count:
            return .arr(zip(x, y).map { lerp($0, $1, t) })
        case let (.obj(x), .obj(y)):
            var out: [String: MotionValue] = [:]
            for (k, v) in x { out[k] = y[k].map { lerp(v, $0, t) } ?? v }
            return .obj(out)
        default:
            return t < 0.5 ? a : b
        }
    }

    /// Mirror a limb spec for the far side in the front view.
    func mirroredLimb() -> MotionValue {
        guard var o = object else { return self }
        for k in ["upper", "fore", "thigh", "shin", "toe", "bend"] {
            if let v = o[k]?.double { o[k] = .num(-v) }
        }
        for k in ["hand", "foot"] {
            guard let v = o[k] else { continue }
            if let p = v.point { o[k] = .arr([.num(-p.x), .num(p.y)]) }
            else if var t = v.object {
                let d = t["d"]?.point ?? .zero
                t["d"] = .arr([.num(-d.x), .num(d.y)])
                o[k] = .obj(t)
            }
        }
        return .obj(o)
    }
}

// MARK: - Library

final class MovementLibrary {
    static let shared = MovementLibrary()

    private let patterns: [String: MotionValue]
    private let exercises: [String: MotionValue]
    private let rules: [MotionValue]
    private var cache: [String: Movement?] = [:]

    private init() {
        let root: MotionValue? = Bundle.main.url(forResource: "movements", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(MotionValue.self, from: $0) }
        patterns = root?["patterns"]?.object ?? [:]
        exercises = root?["exercises"]?.object ?? [:]
        rules = root?["rules"]?.array ?? []
    }

    /// The animation for an exercise: an exact name first, then the keyword rules. Nil when nothing fits.
    func movement(for name: String) -> Movement? {
        if let hit = cache[name] { return hit }
        var patternName: String?
        var equipment: String?
        if let entry = exercises[name] {
            patternName = entry["pattern"]?.string
            equipment = entry["equipment"]?.string
        } else {
            let n = name.lowercased()
            for rule in rules {
                let any = rule["any"]?.array?.compactMap(\.string) ?? []
                let not = rule["not"]?.array?.compactMap(\.string) ?? []
                if any.contains(where: { n.contains($0) }) && !not.contains(where: { n.contains($0) }) {
                    patternName = rule["pattern"]?.string
                    break
                }
            }
            if patternName != nil {
                if n.contains("dumbbell") { equipment = "dumbbell" }
                else if n.contains("kettlebell") { equipment = "kettlebell" }
            }
        }
        let movement = patternName.flatMap { p in patterns[p].map { Movement(name: name, patternName: p, spec: $0, equipmentOverride: equipment) } }
        cache.updateValue(movement, forKey: name)
        return movement
    }
}

// MARK: - Movement (one pattern, ready to play)

final class Movement {
    struct Segment { let from: Int; let to: Int; let t0: Double; let dur: Double; let label: String; let linear: Bool }
    struct Equipment { var type: String; let at: MotionValue?; let from: MP?; let trace: Bool; let angle: Double; let len: Double }
    struct Prop { let type: String; let pts: [MP]; let r: Double }

    let name: String
    let patternName: String
    let view: String
    let keys: [MotionValue]
    let segments: [Segment]
    let total: Double
    let equipment: [Equipment]
    let props: [Prop]
    let work: Set<String>
    let floor: Bool
    private let traceAt: MotionValue?
    private let showTrace: Bool

    struct Bounds { let x0: Double; let x1: Double; let y0: Double; let y1: Double }
    private(set) lazy var bounds: Bounds = computeBounds()
    private(set) lazy var tracePoints: [MP] = computeTrace()

    init(name: String, patternName: String, spec: MotionValue, equipmentOverride: String?) {
        self.name = name
        self.patternName = patternName
        view = spec["view"]?.string ?? "side"
        keys = spec["keys"]?.array ?? []
        work = Set(spec["work"]?.array?.compactMap(\.string) ?? [])
        floor = spec["floor"]?.bool ?? true
        showTrace = spec["showTrace"]?.bool ?? true
        traceAt = spec["trace"]

        var eq: [Equipment] = (spec["equipment"]?.array ?? []).map { e in
            Equipment(type: e["type"]?.string ?? "", at: e["at"], from: e["from"]?.point,
                      trace: e["trace"]?.bool ?? true, angle: e["angle"]?.double ?? 0, len: e["len"]?.double ?? 0.4)
        }
        if let override = equipmentOverride {
            if override == "none" { eq = [] } else if !eq.isEmpty { eq[0].type = override }
        }
        equipment = eq
        props = (spec["props"]?.array ?? []).map { p in
            Prop(type: p["type"]?.string ?? "", pts: p["pts"]?.array?.compactMap(\.point) ?? [], r: p["r"]?.double ?? 0.15)
        }

        // Timeline
        let phases = spec["phases"]?.array?.compactMap(\.string) ?? []
        let seq: [MotionValue] = spec["seq"]?.array ?? [
            .obj(["to": .num(1), "dur": .num(2), "label": .str(phases.first ?? "Lower")]),
            .obj(["hold": .num(0.4)]),
            .obj(["to": .num(0), "dur": .num(1.1), "label": .str(phases.count > 1 ? phases[1] : "Return")]),
            .obj(["hold": .num(0.6)])
        ]
        var segs: [Segment] = []
        var cur = 0, t = 0.0
        for s in seq {
            if let hold = s["hold"]?.double {
                segs.append(Segment(from: cur, to: cur, t0: t, dur: hold, label: segs.last?.label ?? "", linear: false))
                t += hold
            } else {
                let to = Int(s["to"]?.double ?? 0), dur = s["dur"]?.double ?? 1
                segs.append(Segment(from: cur, to: to, t0: t, dur: dur, label: s["label"]?.string ?? "", linear: s["linear"]?.bool ?? false))
                t += dur; cur = to
            }
        }
        segments = segs
        total = max(t, 0.01)
    }

    /// Fraction of the cycle where the first movement ends (the "bottom" pose, used for thumbnails).
    var firstMoveFraction: Double { (segments.first?.dur ?? 0) / total }

    func pose(at time: Double) -> (pose: MotionValue, label: String, cycle: Double) {
        let tt = time.truncatingRemainder(dividingBy: total) + (time < 0 ? total : 0)
        let seg = segments.first(where: { tt >= $0.t0 && tt < $0.t0 + $0.dur }) ?? segments[segments.count - 1]
        let u = seg.dur > 0 ? (tt - seg.t0) / seg.dur : 1
        let e = seg.linear ? u : 0.5 - cos(.pi * u) / 2
        guard keys.indices.contains(seg.from), keys.indices.contains(seg.to) else { return (.null, "", 0) }
        return (MotionValue.lerp(keys[seg.from], keys[seg.to], e), seg.label, tt / total)
    }

    func joints(at time: Double) -> MotionJoints { MotionSolver.solve(pose(at: time).pose, view: view) }

    func point(of j: MotionJoints, _ at: MotionValue?) -> MP {
        guard let at else { return j.arm.end }
        if let s = at.string { return s == "ankle" ? j.leg.end : j.arm.end }
        if let p = at.point { return p }
        let base: MP
        switch at["from"]?.string {
        case "hip": base = j.hip
        case "shoulder": base = j.shoulder
        case "neck": base = j.neck
        case "head": base = j.head
        case "ankle": base = j.leg.end
        default: base = j.arm.end
        }
        let d = at["d"]?.point ?? .zero
        return MP(x: base.x + d.x, y: base.y + d.y)
    }

    private func computeBounds() -> Bounds {
        var x0 = Double.infinity, x1 = -Double.infinity, y0 = Double.infinity, y1 = -Double.infinity
        func eat(_ p: MP) { x0 = min(x0, p.x); x1 = max(x1, p.x); y0 = min(y0, p.y); y1 = max(y1, p.y) }
        let h = MotionSolver.L.head
        for i in 0...40 {
            let j = joints(at: total * Double(i) / 40)
            [j.head, j.neck, j.hip, j.leg.mid, j.leg.end, j.leg.toe ?? j.leg.end, j.legFar.end, j.legFar.toe ?? j.legFar.end,
             j.arm.mid, j.arm.end, j.armFar.end].forEach(eat)
            eat(MP(x: j.head.x + h, y: j.head.y + h)); eat(MP(x: j.head.x - h, y: j.head.y - h))
            for q in equipment {
                let c = point(of: j, q.at)
                let r = q.type == "barbell" && view != "front" ? 0.22 : 0.12
                eat(MP(x: c.x + r, y: c.y + r)); eat(MP(x: c.x - r, y: c.y - r))
                if let f = q.from { eat(f) }
            }
        }
        for p in props { p.pts.forEach(eat) }
        if floor { eat(MP(x: x0, y: 0)) }
        return Bounds(x0: x0, x1: x1, y0: y0, y1: y1)
    }

    private func computeTrace() -> [MP] {
        guard showTrace else { return [] }
        let at: MotionValue?
        if let q = equipment.first(where: { $0.trace }) { at = q.at ?? .str("hand") }
        else if let t = traceAt { at = t }
        else { return [] }
        return (0...80).map { (i: Int) -> MP in
            let j = joints(at: total * Double(i) / 80)
            if let s = at?.string {
                switch s {
                case "shoulder": return j.shoulder
                case "hip": return j.hip
                case "head": return j.head
                case "ankle": return j.leg.end
                default: return j.arm.end
                }
            }
            return point(of: j, at)
        }
    }
}

// MARK: - Solver

struct MotionLimb { var root: MP; var mid: MP; var end: MP; var toe: MP? }

struct MotionJoints {
    var view: String
    var hip, shoulder, neck, head: MP
    var shR: MP?, shL: MP?, hipR: MP?, hipL: MP?
    var leg, legFar, arm, armFar: MotionLimb
}

enum MotionSolver {
    enum L {
        static let shin = 0.44, thigh = 0.44, torso = 0.5, neck = 0.07, head = 0.095
        static let upper = 0.3, fore = 0.28, foot = 0.15, shoulderHalf = 0.17, hipHalf = 0.1
    }

    static func rad(_ d: Double) -> Double { d * .pi / 180 }
    static func limb(_ len: Double, _ deg: Double) -> MP { MP(x: sin(rad(deg)) * len, y: -cos(rad(deg)) * len) }
    static func up(_ len: Double, _ deg: Double) -> MP { MP(x: sin(rad(deg)) * len, y: cos(rad(deg)) * len) }
    static func add(_ a: MP, _ b: MP) -> MP { MP(x: a.x + b.x, y: a.y + b.y) }

    /// Two-link IK. bend > 0 puts the middle joint counter-clockwise of the root→target line.
    static func ik(_ root: MP, _ target: MP, _ a: Double, _ b: Double, _ bend: Double) -> (MP, MP) {
        let dx = target.x - root.x, dy = target.y - root.y
        let d = max(abs(a - b) + 1e-4, min(a + b - 1e-4, hypot(dx, dy)))
        let base = atan2(dy, dx)
        let A = acos(max(-1, min(1, (a * a + d * d - b * b) / (2 * a * d))))
        let ang = base + (bend >= 0 ? A : -A)
        let joint = MP(x: root.x + cos(ang) * a, y: root.y + sin(ang) * a)
        let dir = atan2(target.y - joint.y, target.x - joint.x)
        return (joint, MP(x: joint.x + cos(dir) * b, y: joint.y + sin(dir) * b))
    }

    static func solve(_ p: MotionValue, view: String) -> MotionJoints {
        let front = view == "front"
        let hip = p["hip"]?.point ?? .zero
        let tilt = p["torso"]?.double ?? 0
        let headTilt = p["head"]?.double ?? 0
        let sh = add(add(hip, up(L.torso, tilt)), MP(x: 0, y: p["shrug"]?.double ?? 0))
        let neck = add(sh, up(L.neck, tilt + headTilt * 0.4))
        let head = add(neck, up(L.head, tilt + headTilt))
        var anchors: [String: MP] = ["hip": hip, "shoulder": sh, "neck": neck, "head": head]

        func ref(_ spec: MotionValue) -> MP {
            if let pt = spec.point { return pt }
            let base = anchors[spec["from"]?.string ?? ""] ?? .zero
            return add(base, spec["d"]?.point ?? .zero)
        }
        func solveLeg(_ spec: MotionValue, _ hipPt: MP) -> MotionLimb {
            let knee: MP, ankle: MP
            if let foot = spec["foot"] {
                let r = ik(hipPt, ref(foot), L.thigh, L.shin, spec["bend"]?.double ?? 1)
                knee = r.0; ankle = r.1
            } else {
                knee = add(hipPt, limb(L.thigh, spec["thigh"]?.double ?? 0))
                ankle = add(knee, limb(L.shin, spec["shin"]?.double ?? 0))
            }
            let toe: MP
            if let t = spec["toe"]?.double { toe = add(ankle, limb(L.foot, t)) }
            else if !front && ankle.y < L.foot { toe = MP(x: ankle.x + sqrt(L.foot * L.foot - ankle.y * ankle.y), y: 0) }
            else if front { toe = add(ankle, MP(x: 0, y: -0.02)) }
            else {
                let shinDeg = atan2(ankle.x - knee.x, -(ankle.y - knee.y)) * 180 / .pi
                toe = add(ankle, limb(L.foot, shinDeg + 95))
            }
            return MotionLimb(root: hipPt, mid: knee, end: ankle, toe: toe)
        }
        func solveArm(_ spec: MotionValue, _ shPt: MP) -> MotionLimb {
            if let hand = spec["hand"] {
                let (elbow, h) = ik(shPt, ref(hand), L.upper, L.fore, spec["bend"]?.double ?? -1)
                return MotionLimb(root: shPt, mid: elbow, end: h, toe: nil)
            }
            let elbow = add(shPt, limb(L.upper, spec["upper"]?.double ?? 0))
            return MotionLimb(root: shPt, mid: elbow, end: add(elbow, limb(L.fore, spec["fore"]?.double ?? 0)), toe: nil)
        }

        let legSpec = p["leg"] ?? .obj([:]), armSpec = p["arm"] ?? .obj([:])
        if front {
            let shR = add(sh, MP(x: L.shoulderHalf, y: -0.03)), shL = add(sh, MP(x: -L.shoulderHalf, y: -0.03))
            let hipR = add(hip, MP(x: L.hipHalf, y: 0)), hipL = add(hip, MP(x: -L.hipHalf, y: 0))
            anchors["shoulder"] = shR; anchors["hip"] = hipR
            let leg = solveLeg(legSpec, hipR), arm = solveArm(armSpec, shR)
            anchors["shoulder"] = shL; anchors["hip"] = hipL
            let legFar = solveLeg(p["legFar"] ?? legSpec.mirroredLimb(), hipL)
            let armFar = solveArm(p["armFar"] ?? armSpec.mirroredLimb(), shL)
            return MotionJoints(view: view, hip: hip, shoulder: sh, neck: neck, head: head,
                                shR: shR, shL: shL, hipR: hipR, hipL: hipL, leg: leg, legFar: legFar, arm: arm, armFar: armFar)
        }
        return MotionJoints(view: view, hip: hip, shoulder: sh, neck: neck, head: head,
                            leg: solveLeg(legSpec, hip), legFar: solveLeg(p["legFar"] ?? legSpec, hip),
                            arm: solveArm(armSpec, sh), armFar: solveArm(p["armFar"] ?? armSpec, sh))
    }
}

// MARK: - Drawing

enum MotionRenderer {
    /// Draws one frame of `movement` at `time` (seconds) into the canvas.
    static func draw(_ movement: Movement, time: Double, in ctx: GraphicsContext, size: CGSize, strokeScale: Double = 0.0098) {
        let b = movement.bounds
        let width = Double(size.width), height = Double(max(size.height, 1))
        let aspect = width / height, pad = 0.14
        var w = b.x1 - b.x0 + pad * 2, h = b.y1 - b.y0 + pad * 2
        if w / h > aspect { h = w / aspect } else { w = h * aspect }
        let cx = (b.x0 + b.x1) / 2, cy = (b.y0 + b.y1) / 2
        let s = width / w
        let left = cx - w / 2, top = cy + h / 2
        func P(_ p: MP) -> CGPoint { CGPoint(x: (p.x - left) * s, y: (top - p.y) * s) }
        let sw = w * strokeScale * s

        let ink = VoltColor.label, far = VoltColor.labelTertiary, gold = VoltColor.accent
        func line(_ a: MP, _ c: MP, _ color: Color, _ width: Double, cap: CGLineCap = .round) {
            var path = Path(); path.move(to: P(a)); path.addLine(to: P(c))
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: CGFloat(width), lineCap: cap, lineJoin: .round))
        }
        func circle(_ c: MP, _ r: Double) -> Path {
            let pc = P(c), rr = CGFloat(r * s)
            return Path(ellipseIn: CGRect(x: pc.x - rr, y: pc.y - rr, width: rr * 2, height: rr * 2))
        }
        func lw(_ v: Double) -> CGFloat { CGFloat(v) }

        // Floor and props
        if movement.floor {
            var floor = Path(); floor.move(to: CGPoint(x: 0, y: top * s)); floor.addLine(to: CGPoint(x: width, y: top * s))
            ctx.stroke(floor, with: .color(ink), lineWidth: lw(sw * 0.35))
        }
        for pr in movement.props {
            switch pr.type {
            case "block":
                guard let first = pr.pts.first else { continue }
                var poly = Path(); poly.move(to: P(first)); pr.pts.dropFirst().forEach { poly.addLine(to: P($0)) }; poly.closeSubpath()
                ctx.fill(poly, with: .color(VoltColor.surfaceHigh))
                ctx.stroke(poly, with: .color(VoltColor.border), lineWidth: lw(sw * 0.3))
            case "line":
                guard let first = pr.pts.first else { continue }
                var pl = Path(); pl.move(to: P(first)); pr.pts.dropFirst().forEach { pl.addLine(to: P($0)) }
                ctx.stroke(pl, with: .color(far), style: StrokeStyle(lineWidth: lw(sw * 0.5), lineCap: .square))
            case "circle":
                if let c = pr.pts.first { ctx.stroke(circle(c, pr.r), with: .color(VoltColor.border), lineWidth: lw(sw * 0.5)) }
            case "bar":
                if let c = pr.pts.first {
                    line(MP(x: c.x - 0.12, y: c.y), MP(x: c.x + 0.12, y: c.y), far, sw * 0.5)
                    ctx.fill(circle(c, sw * 0.9 / s), with: .color(ink))
                }
            default: break
            }
        }

        // Implement path
        let trace = movement.tracePoints
        if let first = trace.first {
            var tp = Path(); tp.move(to: P(first)); trace.dropFirst().forEach { tp.addLine(to: P($0)) }
            ctx.stroke(tp, with: .color(gold.opacity(0.85)), style: StrokeStyle(lineWidth: lw(sw * 0.45), dash: [lw(sw * 1.2), lw(sw * 1.6)]))
        }

        let j = movement.joints(at: time)
        let work = movement.work
        func seg(_ name: String, near: Bool) -> Color { near && work.contains(name) ? gold : (near ? ink : far) }
        func drawLeg(_ lg: MotionLimb, near: Bool) {
            line(lg.root, lg.mid, seg("thigh", near: near), sw)
            line(lg.mid, lg.end, (near && work.contains("calf")) ? gold : seg("shin", near: near), sw)
            if let toe = lg.toe { line(lg.end, toe, near ? ink : far, sw) }
        }
        func drawArm(_ am: MotionLimb, near: Bool) {
            line(am.root, am.mid, seg("upper", near: near), sw)
            line(am.mid, am.end, seg("fore", near: near), sw)
        }
        let hands: [MP] = j.view == "front" ? [j.arm.end, j.armFar.end] : [j.arm.end]

        if j.view != "front" { drawLeg(j.legFar, near: false); drawArm(j.armFar, near: false) }

        // Equipment behind the body: cables and side-view plates
        for q in movement.equipment {
            let c = movement.point(of: j, q.at)
            if let from = q.from {
                for (i, hnd) in (q.at == nil || q.at?.string == "hand" ? hands : [c]).enumerated() {
                    let f = (j.view == "front" && i == 1) ? MP(x: -from.x, y: from.y) : from
                    line(f, hnd, far, sw * 0.35)
                    ctx.fill(circle(f, sw * 1.4 / s), with: .color(VoltColor.bg))
                    ctx.stroke(circle(f, sw * 1.4 / s), with: .color(far), lineWidth: lw(sw * 0.4))
                }
            }
            if q.type == "barbell" && j.view != "front" {
                ctx.fill(circle(c, 0.2), with: .color(VoltColor.surfaceHigh.opacity(0.5)))
                ctx.stroke(circle(c, 0.2), with: .color(VoltColor.labelSecondary), lineWidth: lw(sw * 0.55))
            }
        }

        // Body
        if j.view == "front", let hipL = j.hipL, let hipR = j.hipR, let shL = j.shL, let shR = j.shR {
            drawLeg(j.legFar, near: true); drawLeg(j.leg, near: true)
            line(hipL, hipR, ink, sw)
            line(shL, shR, seg("chest", near: true), sw)
            line(j.hip, j.shoulder, seg("torso", near: true), sw)
            drawArm(j.armFar, near: true); drawArm(j.arm, near: true)
        } else {
            drawLeg(j.leg, near: true)
            line(j.hip, j.shoulder, seg("torso", near: true), sw * 1.15)
            drawArm(j.arm, near: true)
        }
        line(j.shoulder, j.neck, ink, sw)
        ctx.fill(circle(j.head, MotionSolver.L.head), with: .color(VoltColor.bg))
        ctx.stroke(circle(j.head, MotionSolver.L.head), with: .color(ink), lineWidth: lw(sw))
        if work.contains("hip") { ctx.fill(circle(j.hip, sw * 1.6 / s), with: .color(gold)) }
        if work.contains("shoulder") { ctx.fill(circle(j.shoulder, sw * 1.6 / s), with: .color(gold)) }

        // Equipment in front
        func rect(_ c: MP, _ w0: Double, _ h0: Double) -> Path {
            let pc = P(c), rw = CGFloat(w0 * s), rh = CGFloat(h0 * s)
            return Path(CGRect(x: pc.x - rw / 2, y: pc.y - rh / 2, width: rw, height: rh))
        }
        for q in movement.equipment {
            let c = movement.point(of: j, q.at)
            let at = (q.at == nil || q.at?.string == "hand") ? hands : [c]
            switch q.type {
            case "barbell":
                if j.view == "front" {
                    let y = hands.map(\.y).reduce(0, +) / Double(hands.count)
                    line(MP(x: -0.62, y: y), MP(x: 0.62, y: y), ink, sw * 0.7)
                    for sx in [-0.645, 0.645] { ctx.fill(rect(MP(x: sx, y: y), 0.05, 0.4), with: .color(ink)) }
                } else {
                    ctx.fill(circle(c, 0.035), with: .color(ink))
                }
            case "dumbbell":
                for hnd in at {
                    let horiz = j.view != "front"
                    let dx = horiz ? 0.08 : 0, dy = horiz ? 0 : 0.08
                    line(MP(x: hnd.x - dx, y: hnd.y - dy), MP(x: hnd.x + dx, y: hnd.y + dy), ink, sw * 0.6)
                    for sgn in [-1.0, 1.0] {
                        ctx.fill(rect(MP(x: hnd.x + sgn * dx, y: hnd.y + sgn * dy), horiz ? 0.06 : 0.12, horiz ? 0.12 : 0.06), with: .color(ink))
                    }
                }
            case "kettlebell":
                for hnd in at {
                    ctx.fill(circle(MP(x: hnd.x, y: hnd.y - 0.11), 0.085), with: .color(ink))
                    var handle = Path()
                    handle.move(to: P(MP(x: hnd.x - 0.05, y: hnd.y - 0.06)))
                    handle.addQuadCurve(to: P(MP(x: hnd.x + 0.05, y: hnd.y - 0.06)), control: P(MP(x: hnd.x, y: hnd.y + 0.03)))
                    ctx.stroke(handle, with: .color(ink), lineWidth: lw(sw * 0.6))
                }
            case "handle", "cable":
                for hnd in at { ctx.fill(rect(hnd, 0.07, 0.07), with: .color(ink)) }
            case "ball":
                let m = hands.count > 1 ? MP(x: (hands[0].x + hands[1].x) / 2, y: (hands[0].y + hands[1].y) / 2) : c
                ctx.fill(circle(m, 0.1), with: .color(VoltColor.surfaceHigh))
                ctx.stroke(circle(m, 0.1), with: .color(ink), lineWidth: lw(sw * 0.7))
            case "wheel":
                let wc = MP(x: c.x, y: c.y - 0.02)
                ctx.fill(circle(wc, 0.09), with: .color(VoltColor.bg))
                ctx.stroke(circle(wc, 0.09), with: .color(ink), lineWidth: lw(sw * 0.8))
            case "pad":
                ctx.fill(circle(c, 0.05), with: .color(VoltColor.surfaceHigh))
                ctx.stroke(circle(c, 0.05), with: .color(ink), lineWidth: lw(sw * 0.5))
            case "platform":
                let a = MotionSolver.rad(q.angle), hl = q.len / 2
                line(MP(x: c.x - cos(a) * hl, y: c.y - sin(a) * hl), MP(x: c.x + cos(a) * hl, y: c.y + sin(a) * hl), ink, sw * 1.4, cap: .square)
            default: break
            }
        }
    }
}

// MARK: - Views

/// The animation surface. Pass `time` in seconds; wrap in a TimelineView to play it.
struct MovementCanvas: View {
    let movement: Movement
    let time: Double
    var strokeScale = 0.0098

    var body: some View {
        Canvas { ctx, size in
            MotionRenderer.draw(movement, time: time, in: ctx, size: size, strokeScale: strokeScale)
        }
        .accessibilityElement()
        .accessibilityLabel("\(movement.name) animation")
    }
}

/// Small still of the working position, used in lists.
struct MovementThumbnail: View {
    let movement: Movement

    var body: some View {
        MovementCanvas(movement: movement, time: movement.firstMoveFraction * movement.total, strokeScale: 0.022)
            .frame(width: 54, height: 36)
            .background(VoltColor.surface)
            .overlay(Rectangle().strokeBorder(VoltColor.border, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Clock that survives pause and speed changes.
private struct MotionClock {
    var offset: Double = 0
    var since = Date()
    var playing = true
    var speed = 1.0

    func time(at now: Date) -> Double { playing ? offset + now.timeIntervalSince(since) * speed : offset }
    mutating func toggle(now: Date = Date()) {
        if playing { offset = time(at: now); playing = false } else { since = now; playing = true }
    }
    mutating func setSpeed(_ v: Double, now: Date = Date()) {
        offset = time(at: now); since = now; speed = v
    }
}

/// Full player for the exercise page: figure, rep count, phase, play/pause and slow motion.
struct MovementPlayer: View {
    let movement: Movement
    @State private var clock = MotionClock()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !clock.playing || reduceMotion)) { context in
                let t = reduceMotion && clock.offset == 0 ? movement.firstMoveFraction * movement.total : clock.time(at: context.date)
                let state = movement.pose(at: t)
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        MovementCanvas(movement: movement, time: t)
                        Text("Rep \(Int(t / movement.total) + 1)")
                            .font(VoltFont.mono(10)).tracking(0.8)
                            .padding(.horizontal, 7).padding(.vertical, 5)
                            .background(VoltColor.bg).foregroundStyle(VoltColor.label)
                            .padding(10)
                    }
                    .aspectRatio(3 / 2, contentMode: .fit)
                    .background(VoltColor.surface)
                    .overlay(Rectangle().strokeBorder(VoltColor.border, lineWidth: 1))

                    HStack(spacing: 12) {
                        Button { clock.toggle() } label: {
                            Image(systemName: clock.playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 10))
                                .frame(width: 28, height: 28)
                                .overlay(Rectangle().strokeBorder(VoltColor.onInk, lineWidth: 1))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(clock.playing ? "Pause demo" : "Play demo")
                        Text(state.label.uppercased())
                        Spacer()
                        Text(String(format: "%.1f S / REP", movement.total)).opacity(0.65)
                    }
                    .font(VoltFont.mono(11)).tracking(0.6)
                    .foregroundStyle(VoltColor.onInk)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(VoltColor.ink)
                }
            }
            VoltSegmented(
                options: [(value: 0.5, label: "Slow · 0.5×"), (value: 1.0, label: "Normal · 1×")],
                selection: Binding(get: { clock.speed }, set: { clock.setSpeed($0) })
            )
        }
    }
}

/// Compact loop for the workout card: no controls, phase label in the corner.
struct MovementLoop: View {
    let movement: Movement
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
            let t = reduceMotion ? movement.firstMoveFraction * movement.total : context.date.timeIntervalSince(start)
            ZStack(alignment: .topLeading) {
                MovementCanvas(movement: movement, time: t)
                Text(movement.pose(at: t).label.uppercased())
                    .font(VoltFont.mono(10)).tracking(0.8)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(VoltColor.bg).foregroundStyle(VoltColor.label)
                    .padding(10)
            }
        }
        .aspectRatio(3 / 2, contentMode: .fit)
    }
}

#Preview("Squat") {
    VStack {
        if let m = MovementLibrary.shared.movement(for: "Squat") { MovementPlayer(movement: m) }
    }
    .padding()
    .background(VoltColor.bg)
}
