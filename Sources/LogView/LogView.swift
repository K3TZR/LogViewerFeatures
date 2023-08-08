//
//  LogView.swift
//  ViewFeatures/LogFeature
//
//  Created by Douglas Adams on 10/10/20.
//  Copyright © 2020-2021 Douglas Adams. All rights reserved.
//

import ComposableArchitecture
import SwiftUI

import Shared

// ----------------------------------------------------------------------------
// MARK: - View

/// A View to display the contents of the app's log
///
public struct LogView: View {  
  let store: StoreOf<LogFeature>
  
  public init(store: StoreOf<LogFeature>) {
    self.store = store
  }

  public var body: some View {
    
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {
        LogHeader(viewStore: viewStore)
        Divider().background(Color(.red))
        Spacer()
        LogBodyView(viewStore: viewStore)
        Spacer()
        Divider().background(Color(.red))
        LogFooter(viewStore: viewStore)
      }
      .onAppear { viewStore.send(.onAppear) }
    }
    .frame(minWidth: 700, maxWidth: .infinity, alignment: .leading)
    .padding(10)
  }
}

struct LogHeader: View {
  let viewStore: ViewStore<LogFeature.State, LogFeature.Action>

  @AppStorage("showTimestamps") var showTimestamps = false
  @AppStorage("logLevel") var logLevel: LogLevel = .debug
  @AppStorage("logFilter") var logFilter: LogFilter = .none
  @AppStorage("logFilterText") var logFilterText = ""

  var body: some View {
    HStack(spacing: 10) {
      Toggle("Show Timestamps", isOn: viewStore.binding(get: {_ in showTimestamps}, send: .showTimestamps ))
      Spacer()
      
      Picker("Show Level", selection: viewStore.binding(
        get: {_ in logLevel },
        send: { .levelPicker($0) } )) {
          ForEach(LogLevel.allCases, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
        .pickerStyle(MenuPickerStyle())
      
      Spacer()
      
      Picker("Filter by", selection: viewStore.binding(
        get: {_ in logFilter },
        send: { .filterPicker($0) } )) {
          ForEach(LogFilter.allCases, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
        .pickerStyle(MenuPickerStyle())
      
      Image(systemName: "x.circle").foregroundColor(logFilterText == "" ? .gray : nil)
        .onTapGesture { viewStore.send(.filterTextField("")) }
      TextField("Filter text", text: viewStore.binding(
        get: {_ in logFilterText },
        send: { .filterTextField($0) }))
      .frame(maxWidth: 300, alignment: .leading)
    }
  }
}

struct LogBodyView: View {
  let viewStore: ViewStore<LogFeature.State, LogFeature.Action>
  
  @AppStorage("fontSize") var fontSize: Double = 12
  @AppStorage("gotoLast") var gotoLast = false

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView([.horizontal, .vertical]) {
        VStack(alignment: .leading) {
          ForEach( viewStore.filteredLines) { message in
            Text(message.text)
              .font(.system(size: fontSize, weight: .regular, design: .monospaced))
              .foregroundColor(message.color)
              .textSelection(.enabled)
          }
          .onChange(of: gotoLast, perform: { _ in
            if viewStore.filteredLines.count > 0 {
              let id = gotoLast ? viewStore.filteredLines.last!.id : viewStore.filteredLines.first!.id
              proxy.scrollTo(id, anchor: .bottomLeading)
            }
          })
          .onChange(of: viewStore.filteredLines.count, perform: { _ in
            if viewStore.filteredLines.count > 0 {
              let id = gotoLast ? viewStore.filteredLines.last!.id : viewStore.filteredLines.first!.id
              proxy.scrollTo(id, anchor: .bottomLeading)
            }
          })
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct LogFooter: View {
  let viewStore: ViewStore<LogFeature.State, LogFeature.Action>

  @AppStorage("autoRefresh") var autoRefresh = false
  @AppStorage("fontSize") var fontSize: Double = 12
  @AppStorage("gotoLast") var gotoLast = false

  var body: some View {
    HStack {
      Stepper("Font Size",
              value: viewStore.binding(
                get: {_ in fontSize },
                send: { .fontSizeStepper($0) }),
              in: 8...14)
      Text(String(format: "%2.0f", fontSize)).frame(alignment: .leading)
      
      Spacer()
      
      HStack {
        Text("Go to \(gotoLast ? "First" : "Last")")
        Image(systemName: gotoLast ? "arrow.up.square" : "arrow.down.square").font(.title)
          .onTapGesture { viewStore.send(.gotoLast) }
      }
      .frame(width: 120, alignment: .trailing)
      Spacer()
      
      HStack(spacing: 20) {
        Button("Refresh") { viewStore.send(.loadButton) }
        Toggle("Auto Refresh", isOn: viewStore.binding(get: {_ in autoRefresh }, send: .autoRefresh))
      }
      Spacer()
      
      HStack(spacing: 20) {
        Button("Load") { viewStore.send(.loadButton) }
        Button("Save") { viewStore.send(.saveButton) }
      }
      
      Spacer()
      Button("Clear") { viewStore.send(.clearButton) }
    }
  }
}

// ----------------------------------------------------------------------------
// MARK: - Preview

struct LogView_Previews: PreviewProvider {
  
  static var previews: some View {
    LogView(store: Store(initialState: LogFeature.State(domain: "net.k3tzr", appName: "Sdr6000", folderUrl: FileManager().urls(for: .downloadsDirectory, in: .userDomainMask).first!)) {
      LogFeature() }
    )
      .frame(minWidth: 975, minHeight: 400)
      .padding()
  }
}
