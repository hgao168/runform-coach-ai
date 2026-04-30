from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.analyzer import analyze_running_video_mock


def main() -> None:
    result = analyze_running_video_mock("sample-running-video.mov")
    print("Summary:", result.summary)
    print("Confidence:", result.confidence)
    print("Metrics:", len(result.metrics))
    print("Issues:", len(result.issues))
    for issue in result.issues:
        print(f"- {issue.title}: {len(issue.recommended_exercises)} exercises")


if __name__ == "__main__":
    main()
