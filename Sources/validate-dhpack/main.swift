import ArgumentParser
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

struct ValidateDHPack: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate-dhpack",
    abstract: "Validate one or more .dhpack files against the DaggerheartModels schema."
  )

  @Argument(help: "One or more .dhpack files to validate.")
  var files: [String]

  mutating func run() throws {
    var failed = false

    for path in files {
      let url = URL(filePath: path)
      do {
        let data = try Data(contentsOf: url)
        let pack = try JSONDecoder().decode(DHPackContent.self, from: data)
        let adversaryCount = pack.adversaries.count
        let environmentCount = pack.environments.count
        print(
          "\(path): OK (\(adversaryCount) adversar\(adversaryCount == 1 ? "y" : "ies"), "
            + "\(environmentCount) environment\(environmentCount == 1 ? "" : "s"))"
        )
      } catch {
        fputs("\(path): FAILED — \(error.localizedDescription)\n", stderr)
        failed = true
      }
    }

    if failed {
      throw ExitCode.failure
    }
  }
}

ValidateDHPack.main()
