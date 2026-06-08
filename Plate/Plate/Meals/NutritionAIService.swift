import Foundation

struct MealNutritionEstimate: Codable, Equatable {
    let name: String
    let description: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let confidence: String
    let portionNotes: String
    let advice: String
}

enum NutritionAIError: LocalizedError {
    case missingEndpoint
    case invalidEndpoint
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            "请先在「每日目标」中填写 AI 服务地址。"
        case .invalidEndpoint:
            "AI 服务地址格式不正确。"
        case .invalidResponse:
            "AI 返回的数据无法读取，请稍后重试。"
        case .server(let message):
            message
        }
    }
}

struct NutritionAIService {
    private struct RequestBody: Encodable {
        let description: String
        let imageBase64: String?
        let bodyWeightKg: Double?
        let currentDailyCalories: Double
        let estimatedDailyBurn: Double
        let locale: String
    }

    private struct ErrorBody: Decodable {
        let error: String?
    }

    var session: URLSession = .shared

    func estimateMeal(
        photoData: Data?,
        description: String,
        bodyWeightKg: Double?,
        currentDailyCalories: Double,
        estimatedDailyBurn: Double
    ) async throws -> MealNutritionEstimate {
        let endpoint = Goals.aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else { throw NutritionAIError.missingEndpoint }
        guard let url = URL(string: endpoint), url.scheme == "https" else {
            throw NutritionAIError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !Goals.aiAccessToken.isEmpty {
            request.setValue(Goals.aiAccessToken, forHTTPHeaderField: "X-Plate-Token")
        }
        request.httpBody = try JSONEncoder().encode(RequestBody(
            description: description,
            imageBase64: photoData?.base64EncodedString(),
            bodyWeightKg: bodyWeightKg,
            currentDailyCalories: currentDailyCalories,
            estimatedDailyBurn: estimatedDailyBurn,
            locale: "zh-CN"
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutritionAIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw NutritionAIError.server(body?.error ?? "AI 估算失败（\(httpResponse.statusCode)）。")
        }
        guard let estimate = try? JSONDecoder().decode(MealNutritionEstimate.self, from: data) else {
            throw NutritionAIError.invalidResponse
        }
        return estimate
    }
}
