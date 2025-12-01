import sys
from pathlib import Path


def main():
    day = int(sys.argv[1])
    path = Path(f"day{day:02}/")
    path.mkdir(exist_ok=True)

    with open("zig_template.zig", "r") as f:
        content = f.read()
    with open(path / "main.zig", "w") as f:
        f.write(content)

    (path / "input.txt").touch()
    (path / "input_test.txt").touch()


if __name__ == '__main__':
    main()