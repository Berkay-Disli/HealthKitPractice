//
//  ActivityView.swift
//  HealthKitPractice
//
//  Created by Berkay Disli on 11.05.2023.
//

import SwiftUI
import HealthKit
import Charts

struct StepData: Identifiable {
    let id = UUID()
    let date: Date
    let stepCount: Int
}

struct ActivityView: View {
    // The health store object
    let healthStore = HKHealthStore()
    
    // The array of step counts for each day
    @State var stepCounts: [Int] = []
    
    // The array of dates for each day
    @State var dates: [Date] = []
    
    @State private var stepDatas: [StepData] = []
    
    // The formatter for displaying dates
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        // A list view that shows the date and step count for each item
        
        ScrollView(showsIndicators: false) {
            LazyVStack {
                ForEach(stepDatas) { item in
                    HStack {
                        Text(dateFormatter.string(from: item.date))
                        Spacer()
                        Text("\(item.stepCount) steps")
                    }
                }
                
                Divider()
                
                
                GroupBox("Step Count") {
                    Chart(stepDatas) { item in
                        BarMark(x: .value("Days", item.date, unit: .day),
                                y: .value("Sleep", item.stepCount))
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
                            if let labelStr = value.as(Int.self) {
                                AxisValueLabel("\(labelStr)")
                            }
                        }
                    }
                }
                .frame(height: 400)
                
            }
        }
        .onAppear {
            print("On appear")
            // Request authorization to read step count data
            requestAuthorization()
            print("Authorization completed")
            
            // Fetch and display the step count data for the past 7 days
            fetchStepCountData()
            print("step counts fetched")
            
        }
    }
    
    // A function that requests authorization to read step count data from HealthKit
    func requestAuthorization() {
        // The quantity type for step count
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        // The types to read from HealthKit
        let typesToRead: Set<HKObjectType> = [stepCountType]
        
        // Check if HealthKit is available on this device
        if HKHealthStore.isHealthDataAvailable() {
            // Request authorization to read the types
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    print("Error requesting authorization: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // A function that fetches and displays the step count data for the past 7 days
    func fetchStepCountData() {
        // The quantity type for step count
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        // The calendar object
        let calendar = Calendar.current
        
        // The current date
        let endDate = Date()
        
        // The date 7 days ago
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) else {
            return
        }
        
        // The predicate for the query (nil means no filter)
        let predicate: NSPredicate? = nil
        
        // The anchor date (the first second of today)
        guard let anchorDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: endDate) else {
            return
        }
        
        // The interval components (one day)
        let interval = DateComponents(day: 1)
        
        // Create the query with the given parameters
        let query = HKStatisticsCollectionQuery(quantityType: stepCountType,
                                                quantitySamplePredicate: predicate,
                                                options: .cumulativeSum,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        
        // Set the initial results handler to process the statistics
        query.initialResultsHandler = { query, results, error in
            
            guard let statsCollection = results else {
                print("Error fetching results: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // An empty array for storing the step counts
            var newStepCounts: [Int] = []
            
            // An empty array for storing the dates
            var newDates: [Date] = []
            
            var stepDatas: [StepData] = []
            
            // Iterate over the statistics from startDate to endDate by one day
            statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, stop in
                // Get the sum quantity for the step count
                if let quantity = statistics.sumQuantity() {
                    // Get the date for the statistics
                    let date = statistics.startDate
                    
                    // Get the value for the step count in the default unit (count)
                    let value = Int(quantity.doubleValue(for: HKUnit.count()))
                    
                    // Append the value and the date to the arrays
                    newStepCounts.append(value)
                    newDates.append(date)
                    stepDatas.append(StepData(date: date, stepCount: value))
                }
            }
            
            // Update the state variables on the main thread
            DispatchQueue.main.async {
                self.stepCounts = newStepCounts
                self.dates = newDates
                self.stepDatas = stepDatas
            }
        }
        
        // Execute the query on the health store
        healthStore.execute(query)
    }
}





struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
    }
}
