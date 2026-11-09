import AppKit

let usage = """
    Usage: segue [command]

      segue                 Print the current input source ID
      segue list            List enabled input sources (ID, label, and name)
      segue select <query>  Switch by ID, label, or name
      segue <query>         Same as select
      segue cycle <group>   Cycle a Segue group (opens Segue if needed)
      segue switcher        Open the quick switcher
      segue help            Show this help

    """

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func labels() -> Dictionary<String, String> {
    guard let data = UserDefaults(suiteName: "com.firatciftci.Segue")?.data(forKey: "labels") else { return [:] }
    return (try? JSONDecoder().decode(Dictionary<String, String>.self, from: data)) ?? [:]
}

func openSegue(_ action: String, _ argument: String? = nil) {
    var components = URLComponents()
    components.scheme = "segue"
    components.host = action
    if let argument { components.queryItems = [URLQueryItem(name: action == "cycle" ? "group" : "source", value: argument)] }
    guard let url = components.url else { fail("Couldn't build the request.") }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    let done = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var failure: (any Error)?
    NSWorkspace.shared.open(url, configuration: configuration) { _, error in
        failure = error
        done.signal()
    }
    done.wait()
    if let failure { fail("Couldn't reach Segue: \(failure.localizedDescription)") }
}

func select(_ query: String) {
    let sources = InputSource.enabled()
    guard let source = InputSource.matching(query, in: sources, labels: labels()) else {
        fail("No enabled input source matches “\(query)”. Run “segue list” to see them.")
    }
    source.select()
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case nil, "current":
    guard let current = InputSource.current() else { fail("Couldn't read the current input source.") }
    print(current.id)
case "list":
    let custom = labels()
    let currentID = InputSource.current()?.id
    for source in InputSource.enabled() {
        let marker = source.id == currentID ? "*" : " "
        print("\(marker) \(source.id)\t\(custom[source.id] ?? source.defaultLabel)\t\(source.name)")
    }
case "select":
    guard arguments.count == 2 else { fail(usage, code: 2) }
    select(arguments[1])
case "cycle":
    guard arguments.count == 2 else { fail(usage, code: 2) }
    openSegue("cycle", arguments[1])
case "switcher":
    openSegue("switcher")
case "help", "-h", "--help":
    print(usage, terminator: "")
case let query?:
    guard arguments.count == 1 else { fail(usage, code: 2) }
    select(query)
}
