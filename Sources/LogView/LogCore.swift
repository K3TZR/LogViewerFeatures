//
//  LogCore.swift
//  ViewFeatures/LogFeature
//
//  Created by Douglas Adams on 11/30/21.
//

import ComposableArchitecture
import SwiftUI

import Shared


public struct LogFeature: Reducer {
  
  @AppStorage("showTimestamps") var showTimestamps = false
  @AppStorage("logLevel") var logLevel: LogLevel = .debug
  @AppStorage("logFilter") var logFilter: LogFilter = .none
  @AppStorage("logFilterText") var logFilterText = ""
  @AppStorage("autoRefresh") var autoRefresh = false
  @AppStorage("gotoLast") var gotoLast = false
  @AppStorage("fontSize") var fontSize: Double = 12
  
  public enum CancelID { case timer } // "dummy" enum used for cancellation
  
  public init() {}
  
  public struct State: Equatable {
    public init(domain: String, appName: String, folderUrl: URL) {
      self.domain = domain
      self.appName = appName
      self.folderUrl = folderUrl
      self.fileUrl = folderUrl.appending(path: appName + ".log" )
    }
    
    public var appName: String
    public var domain: String
    public var fileUrl: URL?
    public var filteredLines = [LogLine]()
    public var folderUrl: URL
    public var lines = [LogLine]()
    public var autoRefreshTask: Task<(), Never>?
  }
  
  public enum Action: Equatable {
    case onAppear
    
    case autoRefresh
    case clearButton
    case filterTextField(String)
    case filterPicker(LogFilter)
    case fontSizeStepper(CGFloat)
    case gotoLast
    case levelPicker(LogLevel)
    case loadButton
    case refresh
    case saveButton
    case showTimestamps
  }
  
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
        
      case .onAppear:
        state.lines = readLogFile(state.fileUrl)
        state.filteredLines = filterLog(state.lines, logFilter, logFilterText, logLevel, showTimestamps)
        return .none
        
      case .autoRefresh:
        autoRefresh.toggle()
        
        if autoRefresh {
          // long running effect to reload once per second
          return .run { send in
            while true {
              await send(.loadButton)
              do {
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
              } catch {
                // ignore errors (only error will be cancellation)
              }
            }
          }.cancellable(id: CancelID.timer, cancelInFlight: true)
          
        } else {
          // cancel the effect
          return .cancel(id: CancelID.timer)
        }
        
      case .clearButton:
        state.filteredLines.removeAll()
        return .none
        
      case .loadButton:
        if state.fileUrl == nil {
          state.fileUrl = showOpenPanel(state.folderUrl)
          state.filteredLines.removeAll()
        } else {
          state.lines.removeAll()
          state.lines = readLogFile(state.fileUrl)
          state.filteredLines = filterLog(state.lines, logFilter, logFilterText, logLevel, showTimestamps)
        }
        return .none
        
      case let .filterPicker(filter):
        logFilter = filter
        state.filteredLines = filterLog(state.lines, logFilter, logFilterText, logLevel, showTimestamps)
        return .none
        
      case let .filterTextField(text):
        logFilterText = text
        state.filteredLines = filterLog(state.lines, logFilter, logFilterText, logLevel, showTimestamps)
        return .none
        
      case let .fontSizeStepper(value):
        fontSize = value
        return .none
        
      case let .levelPicker(level):
        logLevel = level
        state.filteredLines = filterLog(state.lines, logFilter, logFilterText, logLevel, showTimestamps)
        return .none
        
      case .refresh:
        return .none
        
      case .saveButton:
        if let saveURL = showSavePanel() {
          let textArray = state.filteredLines.map { $0.text }
          let fileTextArray = textArray.joined(separator: "\n")
          try? fileTextArray.write(to: saveURL, atomically: true, encoding: .utf8)
        }
        return .none
        
      case .showTimestamps:
        showTimestamps.toggle()
        state.filteredLines = filterLog(state.lines, logFilter, logFilterText, logLevel, showTimestamps)
        return .none
        
      case .gotoLast:
        gotoLast.toggle()
        return .none
      }
    }
  }
}

// ----------------------------------------------------------------------------
// MARK: - Helper functions

//private func getBundleInfo() -> (domain: String, appName: String) {
//  let bundleIdentifier = Bundle.main.bundleIdentifier ?? "net.k3tzr.LogView"
//  let separator = bundleIdentifier.lastIndex(of: ".")!
//  let appName = String(bundleIdentifier.suffix(from: bundleIdentifier.index(separator, offsetBy: 1)))
//  let domain = String(bundleIdentifier.prefix(upTo: separator))
//  return (domain, appName)
//}

private func readLogFile(_ fileUrl: URL?) -> [LogLine] {
var logLines = [LogLine]()
  
  /// Determine the color to assign to a Log entry
  /// - Parameter text:     the entry
  /// - Returns:            a Color
  func logLineColor(_ text: String) -> Color {
    if text.contains("[Debug]") { return .gray }
    else if text.contains("[Info]") { return .primary }
    else if text.contains("[Warning]") { return .orange }
    else if text.contains("[Error]") { return .red }
    else { return .primary }
  }
  
  if fileUrl != nil {
    do {
      // get the contents of the file
      let logString = try String(contentsOf: fileUrl!, encoding: .ascii)
      // parse it into lines
      let entries = logString.components(separatedBy: "\n").dropLast()
      for entry in entries {
        logLines.append(LogLine(text: entry, color: logLineColor(entry)))
      }
      
    } catch {
      fatalError("Unable to read Log file at \(fileUrl!)")
    }
  }
  return logLines
}

/// Filter an array of Log entries
/// - Parameters:
///   - messages:       the array
///   - level:          a log level
///   - filter:         a filter type
///   - filterText:     the filter text
///   - showTimes:      whether to show timestamps
/// - Returns:          the filtered array of Log entries
private func filterLog(_ lines: [LogLine], _ filter: LogFilter, _ filterText: String, _ level: LogLevel, _ showTimeStamps: Bool = true) -> [LogLine] {
  var filteredLines = [LogLine]()
  
  // filter the log entries
  switch level {
  case .debug:     filteredLines = lines
  case .info:      filteredLines = lines.filter { $0.text.contains(" [Error] ") || $0.text.contains(" [Warning] ") || $0.text.contains(" [Info] ") }
  case .warning:   filteredLines = lines.filter { $0.text.contains(" [Error] ") || $0.text.contains(" [Warning] ") }
  case .error:     filteredLines = lines.filter { $0.text.contains(" [Error] ") }
  }
  
  switch filter {
  case .prefix:       filteredLines = filteredLines.filter { $0.text.contains(" > " + filterText) }
  case .includes:     filteredLines = filteredLines.filter { $0.text.contains(filterText) }
  case .excludes:     filteredLines = filteredLines.filter { !$0.text.contains(filterText) }
  case .none:         break
  }
  
  if !showTimeStamps {
    for (i, line) in filteredLines.enumerated() {
      filteredLines[i].text = String(line.text.suffix(from: line.text.firstIndex(of: "[") ?? line.text.startIndex))
    }
  }
  return filteredLines
}

/// Display a SavePanel
/// - Returns:       the URL of the selected file or nil
private func showSavePanel() -> URL? {
  let savePanel = NSSavePanel()
  savePanel.directoryURL = FileManager().urls(for: .desktopDirectory, in: .userDomainMask).first
  savePanel.allowedContentTypes = [.text]
  savePanel.nameFieldStringValue = "Saved.log"
  savePanel.canCreateDirectories = true
  savePanel.isExtensionHidden = false
  savePanel.allowsOtherFileTypes = false
  savePanel.title = "Save the Log"
  
  let response = savePanel.runModal()
  return response == .OK ? savePanel.url : nil
}

/// Display an OpenPanel
/// - Returns:        the URL of the selected file or nil
private func showOpenPanel(_ logFolderUrl: URL) -> URL? {
  let openPanel = NSOpenPanel()
  openPanel.directoryURL = logFolderUrl
  openPanel.allowedContentTypes = [.text]
  openPanel.allowsMultipleSelection = false
  openPanel.canChooseDirectories = false
  openPanel.canChooseFiles = true
  openPanel.title = "Open an existing Log"
  let response = openPanel.runModal()
  return response == .OK ? openPanel.url : nil
}

//private func autoRefreshStart() -> Effect<LogFeature.Action> {
//  return .run { send in
//
//    while true {
//      // a guiClient has been added / updated or deleted
//      await send(.loadButton)
//      try! await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    }
//  }.cancellable(id: CancelId.self)
//}

// ----------------------------------------------------------------------------
// MARK: - Structs and Enums

public struct LogLine: Identifiable, Equatable {
  public var id = UUID()
  var text: String
  var color: Color

  public init(text: String, color: Color = .primary) {
    self.text = text
    self.color = color
  }
}

public enum LogFilter: String, CaseIterable {
  case none
  case includes
  case excludes
  case prefix
}

