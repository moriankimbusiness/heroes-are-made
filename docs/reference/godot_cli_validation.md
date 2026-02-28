# Godot CLI Validation Reference

## 목적

`AGENTS.md`의 R5 정책에서 참조하는 실행 경로/검증 명령/환경 fallback 정보를 보관한다.

## 실행 파일 경로

- Windows
- `C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64.exe`
- `C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64_console.exe`
- WSL 매핑
- `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64.exe`
- `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe`

## 기본 검증 명령

```bash
/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit
```

프로젝트 절대 경로를 명시해야 할 때:

```bash
/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path /mnt/d/04.GameWorkSpaces/00.GodotProjects/heroes-are-made --quit
```

## WSL 실패 시 PowerShell fallback

WSL에서 `UtilBindVsockAnyPort ... socket failed 1` 오류가 나오면 아래를 사용한다.

```bash
powershell.exe -NoProfile -Command "& 'C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\04.GameWorkSpaces\00.GodotProjects\heroes-are-made' --quit"
```

특정 씬만 검증할 때:

```bash
powershell.exe -NoProfile -Command "& 'C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\04.GameWorkSpaces\00.GodotProjects\heroes-are-made' --scene 'res://scenes/levels/level_02.tscn' --quit"
```

## 환경 메모

- 2026-02-22 확인: 현재 WSL 세션에서 직접 실행 시 `WSL ERROR: UtilBindVsockAnyPort ... socket failed 1`가 발생한 이력이 있음.
