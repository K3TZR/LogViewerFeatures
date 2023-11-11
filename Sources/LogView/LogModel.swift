//
//  File.swift
//
//
//  Created by Douglas Adams on 11/10/23.
//

import Foundation
import SwiftUI

import SharedModel
import SettingsModel

@Observable
final public class LogModel {
  // ------------------------------------------------------------------------------
  // MARK: - Singleton
  
  public static var shared = LogModel()
  private init () {}
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  private var logLines = [LogLine]()
  public var filteredLogLines = [LogLine]()
  
  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _settings = SettingsModel.shared
  private var _folderUrl: URL?
  private var _fileUrl: URL?
  private var _autoRefreshTask: Task<(), Never>?


  // ------------------------------------------------------------------------------
  // MARK: - Public methods
  
  public func onAppear(_ folderUrl: URL, _ appName: String) {
    _folderUrl = folderUrl
    _fileUrl = _folderUrl!.appending(path: appName + ".log")
    readLogFile(_fileUrl!)
    filterLog()
  }
  
  public func readLogFile(_ fileUrl: URL) {
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
    
    do {
      // get the contents of the file
      let logString = try String(contentsOf: _fileUrl!, encoding: .ascii)
      // parse it into lines
      let entries = logString.components(separatedBy: "\n").dropLast()
      for entry in entries {
        logLines.append(LogLine(text: entry, color: logLineColor(entry)))
      }
      filterLog()
      
    } catch {
      fatalError("Unable to read Log file at \(_fileUrl!)")
    }
  }
  
  /// Filter an array of Log entries
  public func filterLog() {
    // filter the log entries
    switch _settings.logViewerShowLevel {
    case .debug:     filteredLogLines = logLines
    case .info:      filteredLogLines = logLines.filter { $0.text.contains(" [Error] ") || $0.text.contains(" [Warning] ") || $0.text.contains(" [Info] ") }
    case .warning:   filteredLogLines = logLines.filter { $0.text.contains(" [Error] ") || $0.text.contains(" [Warning] ") }
    case .error:     filteredLogLines = logLines.filter { $0.text.contains(" [Error] ") }
    }
    
    switch _settings.logViewerFilterBy {
    case .prefix:       filteredLogLines = filteredLogLines.filter { $0.text.contains(" > " + _settings.logViewerFilterText) }
    case .includes:     filteredLogLines = filteredLogLines.filter { $0.text.contains(_settings.logViewerFilterText) }
    case .excludes:     filteredLogLines = filteredLogLines.filter { !$0.text.contains(_settings.logViewerFilterText) }
    case .none:         break
    }
    
    if !_settings.logViewerShowTimestamps {
      for (i, line) in filteredLogLines.enumerated() {
        filteredLogLines[i].text = String(line.text.suffix(from: line.text.firstIndex(of: "[") ?? line.text.startIndex))
      }
    }
  }
  
  public func load() {
    if let _folderUrl {
      if let loadUrl = showOpenPanel(_folderUrl) {
        logLines.removeAll()
        readLogFile(loadUrl)
      }
    }
  }

  public func save() {
    if let saveUrl = showSavePanel() {
      let textArray = filteredLogLines.map { $0.text }
      let fileTextArray = textArray.joined(separator: "\n")
      try? fileTextArray.write(to: saveUrl, atomically: true, encoding: .utf8)
    }
  }

  public func refresh() {
    if let _fileUrl {
      logLines.removeAll()
      readLogFile(_fileUrl)
    }
  }
  
  public func clear() {
    filteredLogLines.removeAll()
  }
 
  public func autoRefresh() {
    if _settings.logViewerAutoRefresh {
      autoRefreshStart()
    } else {
      _autoRefreshTask?.cancel()
    }
  }

  // ------------------------------------------------------------------------------
  // MARK: - Private methods
  
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
  
  private func autoRefreshStart() {
    _autoRefreshTask = Task {
      while true {
        // a guiClient has been added / updated or deleted
        await MainActor.run  { refresh() }
        do {
          try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        } catch {
          break
        }
      }
    }
  }
}
