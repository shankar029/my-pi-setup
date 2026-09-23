import { evaluate } from "./rules.ts";

const cases = [
  // [command, shouldBlock, note]
  ['grep -rn "he-vs-assign-panel" --include=* -l . | grep -v node_modules', true, "the real wedge"],
  ['cd /c/x; grep -rn "ActionId" src/', true, "after separator"],
  ['grep -R foo .', true, "-R"],
  ['grep --recursive foo .', true, "--recursive"],
  ['grep -rl foo .', true, "-rl cluster"],
  ['find . -name "*AssignVsLicense*"', true, "find ."],
  ['find / -name x', true, "find /"],
  ['ls -R', true, "ls -R"],
  ['dir /s *.cs', true, "windows dir /s"],
  ['rg -t cs "ActionId"', false, "rg typed"],
  ['fd -g "*.cs"', false, "fd"],
  ['git grep -n "ActionId"', false, "git grep is fast"],
  ['grep -n "ActionId" file.cs', false, "non-recursive grep"],
  ['rg -l foo | grep -v node_modules', false, "grep as a pipe filter"],
  ['cat findings.txt', false, "word 'find' inside a filename"],
  // Accepted over-block: we do not shell-parse quotes. Blocking an echo is harmless and
  // the escape hatch covers it; under-blocking a real `find .` is not harmless.
  ['echo "please find . something"', true, "quoted find: accepted over-block"],
  ['find . -maxdepth 2 -name "*.json"', false, "shallow find allowed"],
  ['find . -maxdepth 9 -name x', true, "deep maxdepth still blocked"],
  ['grep -rn foo . #allow-slow-search', false, "escape hatch"],
  ['git log --oneline -1', false, "git log"],
  ['dotnet test', false, "unrelated"],
  ['npm run build', false, "unrelated"],
];

let pass = 0, fail = 0;
for (const [cmd, expect, note] of cases) {
  const r = evaluate(cmd);
  const blocked = r !== undefined;
  const ok = blocked === expect;
  ok ? pass++ : fail++;
  console.log(`${ok ? "PASS" : "FAIL"}  blocked=${String(blocked).padEnd(5)} want=${String(expect).padEnd(5)} ${(r?.id ?? "-").padEnd(22)} ${note}`);
}
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
