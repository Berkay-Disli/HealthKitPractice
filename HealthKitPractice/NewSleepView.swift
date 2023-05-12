//
//  NewSleepView.swift
//  HealthKitPractice
//
//  Created by Berkay Disli on 11.05.2023.
//

import SwiftUI
import HealthKit
import Charts

struct NewSleepView: View {
    // The health store instance
    let healthStore = HKHealthStore()
    
    // The array of sleep data
    @State var sleepData = [SleepData]()
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    func formatDuration(_ duration: TimeInterval) -> String {
        // Get the hours and minutes from the duration
        let hours = Int(duration / 3600)
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)
        
        // Return a formatted string
        return "\(hours)h \(minutes)m"
    }
    
    var body: some View {
    // A list of sleep rows
      ScrollView(.vertical, showsIndicators: false) {
          LazyVStack {
              ForEach(sleepData) { data in
                SleepRow(data: data)
              }
              
              Divider()
              
              GroupBox("Something..") {
                  Chart(sleepData) { sleepData in
                      BarMark(x: .value("Days", sleepData.date, unit: .day),
                              y: .value("Sleep", sleepData.timeAsleep))
                      .foregroundStyle(.purple)
                  }
                  .chartXAxis {
                      AxisMarks(values: .stride(by: .day)) { value in
                          AxisGridLine().foregroundStyle (.orange)
                          AxisValueLabel(format: .dateTime.weekday(),
                                         centered: true)
                      }
                  }
                  .chartYAxis {
                      AxisMarks(values: .automatic) { value in
                          AxisGridLine().foregroundStyle(.gray)
                          if let labelStr = value.as(TimeInterval.self) {
                              AxisValueLabel(formatDuration(labelStr))
                          }
                      }
                  }
              }
              .frame(height: 400)
          }
      }
      .onAppear(perform: requestAuthorization) // Request permission when the view appears
  }
  
  // A function to request permission to access sleep analysis data
  func requestAuthorization() {
    // The type of data we want to read from HealthKit
    let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    // Request permission from the user
    healthStore.requestAuthorization(toShare: nil, read: [type]) { success, error in
      if success {
        // Permission granted, fetch the sleep data
        fetchSleepData()
      }
    }
  }
  
  // A function to fetch the sleep data from HealthKit
  func fetchSleepData() {
    // The type of data we want to fetch
    let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    // The date range we want to fetch (the past 7 days)
    let now = Date()
    let start = Calendar.current.date(byAdding: .day, value: -7, to: now)!
    let end = now
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    
    // The sort descriptor to sort the results by date
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    
    // The query to fetch the sleep samples
    let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 0, sortDescriptors: [sortDescriptor]) { query, samples, error in
      
      // Process the samples and group them by date and category
      if let samples = samples as? [HKCategorySample] {
        processSleepSamples(samples)
      }
      
    }
    
    // Execute the query on the health store
    healthStore.execute(query)
  }
  
  // A function to process the sleep samples and group them by date and category
  func processSleepSamples(_ samples: [HKCategorySample]) {
    
    // A dictionary to store the sleep data by date
    var dataByDate = [Date: SleepData]()
    
    // Iterate through the samples
    for sample in samples {
      
      // Get the start and end date of the sample
      let startDate = sample.startDate
      let endDate = sample.endDate
      
      // Get the category value of the sample (in bed, asleep, awake, etc.)
      let value = sample.value
      
      // Get the date components of the start date (we only care about the day, month and year)
      let components = Calendar.current.dateComponents([.day, .month, .year], from: startDate)
      
      // Get the date from the components (this will be used as a key for grouping samples by date)
      let date = Calendar.current.date(from: components)!
      
      // Get or create a SleepData object for this date
      var data = dataByDate[date] ?? SleepData(date: date)
      
      // Add a SleepSegment object for this sample (a segment represents a period of time with a specific category)
      data.segments.append(SleepSegment(value: value, start: startDate, end:endDate))
        
        // Update the data for this date
        dataByDate[date] = data
      }
      
      // Convert the dictionary values to an array and sort it by date
      let sortedData = Array(dataByDate.values).sorted(by: { $0.date > $1.date })
      
      // Update the state variable to refresh the view
      DispatchQueue.main.async {
        self.sleepData = sortedData
      }
    }
  }

  // A struct to represent a sleep data for a given date
  struct SleepData: Identifiable {
    // A unique id for SwiftUI
    let id = UUID()
    
    // The date of the sleep data
    let date: Date
    
    // The array of sleep segments for this date
    var segments = [SleepSegment]()
    
    // A computed property to get the total time in bed (in seconds)
    var timeInBed: TimeInterval {
      // Filter the segments by the inBed category
      let inBedSegments = segments.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
      
      // Sum up the durations of the segments
      let inBedDuration = inBedSegments.reduce(0) { $0 + $1.duration }
      
      // Return the total duration
      return inBedDuration
    }
    
    // A computed property to get the total time asleep (in seconds)
    var timeAsleep: TimeInterval {
      // Filter the segments by the asleep category
        let asleepSegments = segments.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
      
      // Sum up the durations of the segments
      let asleepDuration = asleepSegments.reduce(0) { $0 + $1.duration }
      
      // Return the total duration
      return asleepDuration
    }
  }

  // A struct to represent a sleep segment (a period of time with a specific category)
  struct SleepSegment {
    // The category value of the segment (in bed, asleep, awake, etc.)
    let value: Int
    
    // The start and end date of the segment
    let start: Date
    let end: Date
    
    // A computed property to get the duration of the segment (in seconds)
    var duration: TimeInterval {
      return end.timeIntervalSince(start)
    }
  }


// A SwiftUI view to display a sleep data as a row
struct SleepRow: View {
  
  // The sleep data to display
  let data: SleepData
  
  // The date formatter to format the date as a string
  let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
  }()
  
  var body: some View {
    // A horizontal stack of views
    HStack {
      // A vertical stack of views for the date and time in bed
      VStack(alignment: .leading) {
        // Display the date as a text view using the date formatter
        Text(dateFormatter.string(from: data.date))
          .font(.headline)
        
        // Display the time in bed as a text view
        Text("Time in bed: \(formatDuration(data.timeInBed))")
          .font(.subheadline)
      }
      
      Spacer()
      
      // A vertical stack of views for the time asleep and efficiency
      VStack(alignment: .trailing) {
        // Display the time asleep as a text view
        Text("Time asleep: \(formatDuration(data.timeAsleep))")
          .font(.headline)
        
        // Calculate and display the sleep efficiency as a text view
        let efficiency = data.timeAsleep / data.timeInBed * 100
        
        Text("Efficiency: \(String(format: "%.1f", efficiency))%")
          .font(.subheadline)
      }
    }
    .padding()
  }
  
  // A helper function to format a duration (in seconds) as a string (in hours and minutes)
  func formatDuration(_ duration: TimeInterval) -> String {
    // Get the hours and minutes from the duration
    let hours = Int(duration / 3600)
    let minutes = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)
    
    // Return a formatted string
    return "\(hours)h \(minutes)m"
  }
}



struct NewSleepView_Previews: PreviewProvider {
    static var previews: some View {
        NewSleepView()
    }
}
