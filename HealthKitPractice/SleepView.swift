//
//  SleepView.swift
//  HealthKitPractice
//
//  Created by Berkay Disli on 11.05.2023.
//

import SwiftUI
import HealthKit

struct SleepView: View {
    @State var sleepData: [HKCategorySample] = []
    let healthStore = HKHealthStore()

    var body: some View {
        VStack {
            Text("Sleep Data")
                .font(.title)
                .padding()

            List(sleepData, id: \.self) { data in
                VStack(alignment: .leading) {
                    Text("Start Date: \(data.startDate, formatter: dateFormatter)")
                    Text("End Date: \(data.endDate, formatter: dateFormatter)")
                    Text("Category Value: \(data.value)")
                }
            }
            .padding()

            Button(action: {
                self.authorizeHealthKit()
            }, label: {
                Text("Authorize HealthKit Access")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            })
            .padding()
        }
        .onAppear {
            self.requestSleepData()
        }
    }

    func requestSleepData() {
        let sleepCategoryType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sleepCategoryType, predicate: nil, limit: 10, sortDescriptors: [sortDescriptor]) { query, results, error in
            if let samples = results as? [HKCategorySample] {
                DispatchQueue.main.async {
                    self.sleepData = samples
                }
            }
        }
        healthStore.execute(query)
    }

    func authorizeHealthKit() {
        let healthKitTypesToRead: Set<HKObjectType> = [HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!]
        healthStore.requestAuthorization(toShare: nil, read: healthKitTypesToRead) { success, error in
            if let error = error {
                print(error.localizedDescription)
            }
            if success {
                print("HealthKit access authorized")
                self.requestSleepData()
            } else {
                print("HealthKit access denied")
            }
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct SleepView_Previews: PreviewProvider {
    static var previews: some View {
        SleepView()
    }
}
