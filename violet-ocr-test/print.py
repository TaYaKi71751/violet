import argparse
import json

parser = argparse.ArgumentParser()
parser.add_argument("input", help="raw json 경로")
parser.add_argument("--min-conf", type=float, default=0.8, help="최소 신뢰도 (기본: 0.8)")
parser.add_argument("--min-len", type=int, default=3, help="최소 글자수 (기본: 3)")
args = parser.parse_args()

with open(args.input, encoding="utf-8") as f:
    data = json.load(f)

lines = []
for page in data["pages"]:
    for d in page["dialogues"]:
        if d["confidence"] >= args.min_conf and len(d["text"]) >= args.min_len:
            lines.append(d["text"])

output_path = "dialog.log"
with open(output_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"{len(lines)}개 대사 → {output_path}")
