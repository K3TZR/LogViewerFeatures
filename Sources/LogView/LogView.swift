//
//  LogView.swift
//  ViewFeatures/LogFeature
//
//  Created by Douglas Adams on 10/10/20.
//  Copyright © 2020-2021 Douglas Adams. All rights reserved.
//

import ComposableArchitecture
import SwiftUI

import SettingsModel
import SharedModel

// ----------------------------------------------------------------------------
// MARK: - View

/// A View to display the contents of the app's log
///
public struct LogView: View {
  let domain: String
  let appName: String
  let folderUrl: URL

  public init(domain: String, appName: String, folderUrl: URL) {
    self.domain = domain
    self.appName = appName
    self.folderUrl = folderUrl
  }
  
  @Environment(LogModel.self) var logModel
  
  public var body: some View {
    
    VStack {
      LogHeader()
      Divider().background(Color(.red))
      Spacer()
      LogBodyView()
      Spacer()
      Divider().background(Color(.red))
      LogFooter()
    }
    .onAppear { logModel.onAppear(folderUrl, appName) }
    .frame(minWidth: 700, maxWidth: .infinity, alignment: .leading)
    .padding(10)
  }
}

struct LogHeader: View {

  @Environment(LogModel.self) var logModel
  @Environment(SettingsModel.self) var settings
  
  var body: some View {
    @Bindable var settingsBindable = settings
    
    HStack(spacing: 10) {
      Toggle("Show Timestamps", isOn: $settingsBindable.logViewerShowTimestamps )
      Spacer()
      
      Picker("Show Level", selection: $settingsBindable.logViewerShowLevel) {
          ForEach(LogLevel.allCases, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
        .pickerStyle(MenuPickerStyle())
      
      Spacer()
      
      Picker("Filter by", selection: $settingsBindable.logViewerFilterBy) {
          ForEach(LogFilter.allCases, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
        .pickerStyle(MenuPickerStyle())
      
      Image(systemName: "x.circle").foregroundColor(settings.logViewerFilterText == "" ? .gray : nil)
        .onTapGesture { settings.logViewerFilterText = "" }
      TextField("Filter text", text: $settingsBindable.logViewerFilterText)
      .frame(maxWidth: 300, alignment: .leading)
    }
    .onChange(of: settings.logViewerShowTimestamps) {
      logModel.filterLog()
    }
    .onChange(of: settings.logViewerShowLevel) {
      logModel.filterLog()
    }
    .onChange(of: settings.logViewerFilterBy) {
      logModel.filterLog()
    }
    .onChange(of: settings.logViewerFilterText) {
      logModel.filterLog()
    }
  }
}

struct LogBodyView: View {
  
  @Environment(SettingsModel.self) var settings

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView([.horizontal, .vertical]) {
        VStack(alignment: .leading) {
          ForEach( LogModel.shared.filteredLogLines) { message in
            Text(message.text)
              .font(.system(size: settings.logViewerFontSize, weight: .regular, design: .monospaced))
              .foregroundColor(message.color)
              .textSelection(.enabled)
          }
          .onChange(of: settings.logViewerGoToLast) {
            if LogModel.shared.filteredLogLines.count > 0 {
              let id = settings.logViewerGoToLast ? LogModel.shared.filteredLogLines.last!.id : LogModel.shared.filteredLogLines.first!.id
              proxy.scrollTo(id, anchor: .bottomLeading)
            }
          }
          .onChange(of: LogModel.shared.filteredLogLines.count) {
            if LogModel.shared.filteredLogLines.count > 0 {
              let id = settings.logViewerGoToLast ? LogModel.shared.filteredLogLines.last!.id : LogModel.shared.filteredLogLines.first!.id
              proxy.scrollTo(id, anchor: .bottomLeading)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct LogFooter: View {

  @Environment(LogModel.self) var logModel
  @Environment(SettingsModel.self) var settings

  var body: some View {
    @Bindable var settingsBindable = settings

    HStack {
      Stepper("Font Size", value: $settingsBindable.logViewerFontSize, in: 8...14)
      Text(String(format: "%2.0f", settings.logViewerFontSize)).frame(alignment: .leading)
      
      Spacer()
      
      HStack {
        Text("Go to \(settings.logViewerGoToLast ? "First" : "Last")")
        Image(systemName: settings.logViewerGoToLast ? "arrow.up.square" : "arrow.down.square").font(.title)
          .onTapGesture { settings.logViewerGoToLast.toggle() }
      }
      .frame(width: 120, alignment: .trailing)
      Spacer()
      
      HStack(spacing: 20) {
        Button("Refresh") { logModel.refresh() }
        Toggle("Auto Refresh", isOn: $settingsBindable.logViewerAutoRefresh)
      }
      Spacer()
      
      HStack(spacing: 20) {
        Button("Load") { logModel.load() }
        Button("Save") { logModel.save() }
      }
      
      Spacer()
      Button("Clear") { logModel.clear() }
    }
    .onChange(of: settings.logViewerAutoRefresh) {
      logModel.autoRefresh()
    }

  }
}

// ----------------------------------------------------------------------------
// MARK: - Preview

#Preview {
  LogView(domain: "net.k3tzr",
          appName: "Sdr6000",
          folderUrl: FileManager().urls(for: .downloadsDirectory, in: .userDomainMask).first!)
  .frame(minWidth: 975, minHeight: 400)
  .padding()
}
