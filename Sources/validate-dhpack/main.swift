import DaggerheartModels
import Foundation

// validate-dhpack — validates one or more .dhpack files against the DaggerheartModels schema.
//
// Usage: validate-dhpack <file.dhpack> [<file2.dhpack> ...]
// Exit 0: all files are valid JSON and decode without error.
// Exit 1: one or more files failed validation (errors printed to stderr).
//
// Full field-level validation (required fields, value ranges) is tracked in
// https://github.com/gwillish/DaggerheartModels/issues/5

guard CommandLine.arguments.count > 1 else {
  fputs("usage: validate-dhpack <file.dhpack> [...]\n", stderr)
  exit(1)
}

var failed = false

for path in CommandLine.arguments.dropFirst() {
  let url = URL(filePath: path)
  do {
    let data = try Data(contentsOf: url)
    let pack = try JSONDecoder().decode(DHPackContent.self, from: data)
    let adversaryCount = pack.adversaries.count
    let environmentCount = pack.environments.count
    print(
      "\(path): OK (\(adversaryCount) adversar\(adversaryCount == 1 ? "y" : "ies"), \(environmentCount) environment\(environmentCount == 1 ? "" : "s"))"
    )
  } catch {
    fputs("\(path): FAILED — \(error.localizedDescription)\n", stderr)
    failed = true
  }
}

exit(failed ? 1 : 0)
