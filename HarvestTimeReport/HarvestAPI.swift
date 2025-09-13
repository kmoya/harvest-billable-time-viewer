//
//  HarvestAPI.swift
//  HarvestTimeReport
//
//  Created by Kent Moya on 9/13/25.
//  Licensed under the MIT License
//

import Foundation

class HarvestAPI {
    private var accountID: String?
    private var apiToken: String?
    private var userAgent: String?
    
    // Harvest API response structures
    struct HarvestTimeReportResponse: Codable {
        let results: [TimeReportResult]
    }
    
    struct TimeReportResult: Codable {
        let billable_hours: Double
        let client_name: String?
        let project_name: String?
    }
    
    enum HarvestAPIError: Error {
        case missingCredentials
        case invalidURL
        case noData
        case invalidResponse
        case httpError(Int)
        case decodingError(Error)
        case networkError(Error)
        
        var localizedDescription: String {
            switch self {
            case .missingCredentials:
                return "API credentials are missing. Please configure your Account ID and API Token."
            case .invalidURL:
                return "Invalid API URL"
            case .noData:
                return "No data received from API"
            case .invalidResponse:
                return "Invalid response from API"
            case .httpError(let code):
                return "HTTP error \(code). Please check your credentials and try again."
            case .decodingError(let error):
                return "Failed to parse API response: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    init() {
        updateCredentials()
    }
    
    func updateCredentials() {
        accountID = UserDefaults.standard.string(forKey: "HarvestAccountID")
        apiToken = UserDefaults.standard.string(forKey: "HarvestAPIToken")
        userAgent = UserDefaults.standard.string(forKey: "HarvestUserAgent")
    }
    
    func hasValidCredentials() -> Bool {
        let hasAccount = accountID?.isEmpty == false
        let hasToken = apiToken?.isEmpty == false  
        let hasAgent = userAgent?.isEmpty == false
        return hasAccount && hasToken && hasAgent
    }
    
    func fetchBillableHours(for period: TimePeriod = .month, completion: @escaping (Result<Double, Error>) -> Void) {
        guard let accountID = accountID, !accountID.isEmpty,
              let apiToken = apiToken, !apiToken.isEmpty,
              let userAgent = userAgent, !userAgent.isEmpty else {
            completion(.failure(HarvestAPIError.missingCredentials))
            return
        }
        
        let (startDate, endDate) = getDateRange(for: period)
        fetchBillableHours(from: startDate, to: endDate, completion: completion)
    }
    
    private func getDateRange(for period: TimePeriod) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .day:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return (startOfDay, endOfDay)
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            return (startOfWeek, endOfWeek)
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (startOfMonth, endOfMonth)
        }
    }
    
    func fetchBillableHours(completion: @escaping (Result<Double, Error>) -> Void) {
        guard let accountID = accountID, !accountID.isEmpty,
              let apiToken = apiToken, !apiToken.isEmpty,
              let userAgent = userAgent, !userAgent.isEmpty else {
            completion(.failure(HarvestAPIError.missingCredentials))
            return
        }
        
        // Get current month date range
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        // Create date formatter for API query
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromString = dateFormatter.string(from: startOfMonth)
        let toString = dateFormatter.string(from: endOfMonth)
        
        // Build the API URL for time reports (current month)
        guard let url = URL(string: "https://api.harvestapp.com/v2/reports/time/projects?from=\(fromString)&to=\(toString)") else {
            completion(.failure(HarvestAPIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accountID, forHTTPHeaderField: "Harvest-Account-ID")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(HarvestAPIError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(HarvestAPIError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(HarvestAPIError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(HarvestAPIError.noData))
                return
            }
            
            do {
                let reportResponse = try JSONDecoder().decode(HarvestTimeReportResponse.self, from: data)
                
                // Calculate total billable hours from all results
                let totalBillableHours = reportResponse.results.reduce(0.0) { sum, result in
                    return sum + result.billable_hours
                }
                
                completion(.success(totalBillableHours))
            } catch {
                completion(.failure(HarvestAPIError.decodingError(error)))
            }
        }
        
        task.resume()
    }
    
    // Helper method to fetch time reports for a date range
    func fetchBillableHours(from startDate: Date, to endDate: Date, completion: @escaping (Result<Double, Error>) -> Void) {
        guard let accountID = accountID, !accountID.isEmpty,
              let apiToken = apiToken, !apiToken.isEmpty,
              let userAgent = userAgent, !userAgent.isEmpty else {
            completion(.failure(HarvestAPIError.missingCredentials))
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromString = dateFormatter.string(from: startDate)
        let toString = dateFormatter.string(from: endDate)
        
        guard let url = URL(string: "https://api.harvestapp.com/v2/reports/time/projects?from=\(fromString)&to=\(toString)") else {
            completion(.failure(HarvestAPIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accountID, forHTTPHeaderField: "Harvest-Account-ID")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(HarvestAPIError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(HarvestAPIError.invalidResponse))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(HarvestAPIError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(HarvestAPIError.noData))
                return
            }
            
            do {
                let reportResponse = try JSONDecoder().decode(HarvestTimeReportResponse.self, from: data)
                
                let totalBillableHours = reportResponse.results.reduce(0.0) { sum, result in
                    return sum + result.billable_hours
                }
                
                completion(.success(totalBillableHours))
            } catch {
                completion(.failure(HarvestAPIError.decodingError(error)))
            }
        }
        
        task.resume()
    }
}
