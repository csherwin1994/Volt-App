#!/usr/bin/env python3
"""
Build Volt/Resources/exercises.json from free-exercise-db (https://github.com/yuhonas/free-exercise-db),
which is released into the public domain (The Unlicense).

Usage:
  git clone --depth 1 https://github.com/yuhonas/free-exercise-db /tmp/free-exercise-db
  python3 tools/build_exercise_catalog.py /tmp/free-exercise-db/dist/exercises.json

Each entry keeps the source's fields and adds `group` and `equipmentType`, the app's own
muscle-group and equipment categories, so the Swift side needs no mapping tables.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Volt" / "Resources" / "exercises.json"

# Detailed muscle → the app's Exercise.MuscleGroup raw value
GROUP = {
    "chest": "Chest",
    "lats": "Back", "middle back": "Back", "lower back": "Back", "traps": "Back",
    "shoulders": "Shoulders", "neck": "Shoulders",
    "biceps": "Biceps", "forearms": "Biceps",
    "triceps": "Triceps",
    "quadriceps": "Legs", "hamstrings": "Legs", "calves": "Legs", "adductors": "Legs", "abductors": "Legs",
    "glutes": "Glutes",
    "abdominals": "Core",
}

# Source equipment → the app's Exercise.Equipment raw value
EQUIPMENT = {
    "barbell": "Barbell", "e-z curl bar": "Barbell",
    "dumbbell": "Dumbbell",
    "machine": "Machine",
    "cable": "Cable/Pulley",
    "body only": "Bodyweight",
    "kettlebells": "Kettlebell",
    "bands": "Bands",
}

FULL_BODY_CATEGORIES = {"olympic weightlifting", "strongman"}

# Volt's built-in exercise names → the same movement in free-exercise-db.
# A matched entry is published under the Volt name, so existing workout history lines up
# and the built-in exercise gains the catalog's instructions and photos instead of being duplicated.
ALIASES = {
    "Bench Press": "Barbell Bench Press - Medium Grip",
    "Incline Bench Press": "Barbell Incline Bench Press - Medium Grip",
    "Decline Bench Press": "Decline Barbell Bench Press",
    "Close Grip Bench Press": "Close-Grip Barbell Bench Press",
    "Smith Machine Bench Press": "Smith Machine Bench Press",
    "Dumbbell Bench Press": "Dumbbell Bench Press",
    "Incline Dumbbell Press": "Incline Dumbbell Press",
    "Decline Dumbbell Press": "Decline Dumbbell Bench Press",
    "Dumbbell Fly": "Dumbbell Flyes",
    "Incline Dumbbell Fly": "Incline Dumbbell Flyes",
    "Push Up": "Pushups",
    "Wide Push Up": "Push-Up Wide",
    "Decline Push Up": "Decline Push-Up",
    "Svend Press": "Svend Press",
    "Rack Pull": "Rack Pulls",
    "Romanian Deadlift": "Romanian Deadlift",
    "Sumo Deadlift": "Sumo Deadlift",
    "Good Morning": "Good Morning",
    "Barbell Row": "Bent Over Barbell Row",
    "Dumbbell Row": "One-Arm Dumbbell Row",
    "Pull Up": "Pullups",
    "Chin Up": "Chin-Up",
    "Lat Pulldown": "Wide-Grip Lat Pulldown",
    "Close Grip Lat Pulldown": "Close-Grip Front Lat Pulldown",
    "Seated Cable Row": "Seated Cable Rows",
    "Straight Arm Pulldown": "Straight-Arm Pulldown",
    "Face Pull": "Face Pull",
    "Reverse Fly": "Reverse Flyes",
    "Back Extension": "Hyperextensions (Back Extensions)",
    "Band Pull Apart": "Band Pull Apart",
    "Overhead Press": "Standing Military Press",
    "Push Press": "Push Press",
    "Upright Row": "Upright Barbell Row",
    "Dumbbell Shoulder Press": "Dumbbell Shoulder Press",
    "Arnold Press": "Arnold Dumbbell Press",
    "Lateral Raise": "Side Lateral Raise",
    "Front Raise": "Front Dumbbell Raise",
    "Machine Shoulder Press": "Machine Shoulder (Military) Press",
    "Plate Front Raise": "Front Plate Raise",
    "Handstand Push Up": "Handstand Push-Ups",
    "Barbell Curl": "Barbell Curl",
    "EZ Bar Curl": "EZ-Bar Curl",
    "Reverse Barbell Curl": "Reverse Barbell Curl",
    "Dumbbell Curl": "Dumbbell Bicep Curl",
    "Incline Dumbbell Curl": "Incline Dumbbell Curl",
    "Hammer Curl": "Hammer Curls",
    "Zottman Curl": "Zottman Curl",
    "Concentration Curl": "Concentration Curls",
    "Spider Curl": "Spider Curl",
    "Preacher Curl": "Preacher Curl",
    "Machine Curl": "Machine Bicep Curl",
    "EZ Bar Skull Crusher": "EZ-Bar Skullcrusher",
    "JM Press": "JM Press",
    "Tricep Pushdown": "Triceps Pushdown",
    "Rope Pushdown": "Triceps Pushdown - Rope Attachment",
    "Reverse Grip Pushdown": "Reverse Grip Triceps Pushdown",
    "Cable Overhead Tricep Extension": "Cable Rope Overhead Triceps Extension",
    "Tate Press": "Tate Press",
    "Bench Dip": "Bench Dips",
    "Squat": "Barbell Squat",
    "Front Squat": "Front Barbell Squat",
    "Box Squat": "Box Squat",
    "Hack Squat": "Hack Squat",
    "Smith Machine Squat": "Smith Machine Squat",
    "Goblet Squat": "Goblet Squat",
    "Leg Press": "Leg Press",
    "Leg Extension": "Leg Extensions",
    "Leg Curl": "Lying Leg Curls",
    "Seated Leg Curl": "Seated Leg Curl",
    "Calf Raise": "Standing Calf Raises",
    "Seated Calf Raise": "Seated Calf Raise",
    "Donkey Calf Raise": "Donkey Calf Raises",
    "Glute-Ham Raise": "Glute Ham Raise",
    "Stiff Leg Deadlift": "Stiff-Legged Barbell Deadlift",
    "Hip Thrust": "Barbell Hip Thrust",
    "Single Leg Glute Bridge": "Single Leg Glute Bridge",
    "Plank": "Plank",
    "Crunch": "Crunches",
    "Decline Crunch": "Decline Crunch",
    "Oblique Crunch": "Oblique Crunches",
    "Sit Up": "Sit-Up",
    "Dead Bug": "Dead Bug",
    "Ab Rollout": "Ab Roller",
    "Hanging Leg Raise": "Hanging Leg Raise",
    "Russian Twist": "Russian Twist",
    "Cable Crunch": "Cable Crunch",
    "Cable Woodchop": "Standing Cable Wood Chop",
    "Pallof Press": "Pallof Press",
    "Power Clean": "Power Clean",
    "Clean and Jerk": "Clean and Jerk",
    "Snatch": "Snatch",
    "Farmer's Walk": "Farmer's Walk",
    "Battle Ropes": "Battling Ropes",
    "Sled Push": "Sled Push",
    "Tire Flip": "Tire Flip",
    "Treadmill": "Running, Treadmill",
    "Cycling": "Bicycling",
    "Elliptical": "Elliptical Trainer",
    "Stair Climber": "Stairmaster",
    "Rowing Machine": "Rowing, Stationary",
    "Assault Bike": "Air Bike",
}


def group_for(ex):
    if ex.get("category") == "cardio":
        return "Cardio"
    primary = ex.get("primaryMuscles") or []
    groups = {GROUP.get(m) for m in primary + (ex.get("secondaryMuscles") or []) if GROUP.get(m)}
    if ex.get("category") in FULL_BODY_CATEGORIES and len(groups) >= 3:
        return "Full Body"
    for m in primary:
        if m in GROUP:
            return GROUP[m]
    return "Full Body"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = json.loads(Path(sys.argv[1]).read_text())
    by_source_name = {ex["name"].strip(): ex for ex in source}
    missing = [src for src in ALIASES.values() if src not in by_source_name]
    if missing:
        sys.exit(f"ALIASES point at names not in the source: {missing}")
    volt_name = {src: volt for volt, src in ALIASES.items()}
    out = []
    for ex in source:
        source_name = ex["name"].strip()
        out.append({
            "id": ex["id"],
            "name": volt_name.get(source_name, source_name),
            "sourceName": source_name,
            "group": group_for(ex),
            "equipmentType": EQUIPMENT.get(ex.get("equipment") or "", "Other"),
            "equipment": ex.get("equipment") or "none",
            "primaryMuscles": ex.get("primaryMuscles") or [],
            "secondaryMuscles": ex.get("secondaryMuscles") or [],
            "level": ex.get("level") or "",
            "mechanic": ex.get("mechanic") or "",
            "force": ex.get("force") or "",
            "category": ex.get("category") or "strength",
            "instructions": [step.strip() for step in ex.get("instructions") or [] if step.strip()],
            "images": ex.get("images") or [],
        })
    names = [e["name"].lower() for e in out]
    clashes = sorted({n for n in names if names.count(n) > 1})
    if clashes:
        sys.exit(f"Duplicate names after aliasing: {clashes}")
    out.sort(key=lambda e: e["name"].lower())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"source": "free-exercise-db (public domain)", "version": 1, "exercises": out},
                              ensure_ascii=False, separators=(",", ":")))
    print(f"{len(ALIASES)} built-in exercises matched to catalog entries")
    print(f"Wrote {len(out)} exercises to {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
