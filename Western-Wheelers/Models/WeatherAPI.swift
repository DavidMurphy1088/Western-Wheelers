import Foundation
import Combine

class WeatherAPI  : NSObject, ObservableObject {
    let weatherDaysLoaded = PassthroughSubject<Int?, Never>()
    var weatherData: WeatherData? = nil
    
    struct DayWeatherImage: Decodable {
        var main: String
        //var description: String
        //var icon: String
    }

    struct Temp: Decodable {
        var day: Float
        //var min: Float
        var max: Float
    }
    
    struct DayWeather: Decodable {
        var dt: Int
        //var clouds: Float
        //var uvi: Float
        //var pressure: Int
        //var rain: Float? // was there once but no longer??
        var weather: [DayWeatherImage]
        var temp: Temp
    }

    struct Current: Decodable {
        var dt: Int
        var temp: Float
    }
    
    struct WeatherData: Decodable {
        var daily: [DayWeather]
        //var current: Current
    }
    
    func notifyObservers(count: Int) { //}? = nil, msg: String? = nil) {
        DispatchQueue.main.async {
            self.weatherDaysLoaded.send(count)
        }
    }
    
    func load() {
        //run in background thread to keep weather updates keep occuring and current
        let dispatchQueue = DispatchQueue(label: "weather loader", qos: .background)
        
        dispatchQueue.async {
            // Palo Alto lat, long locn
            let urlStr = "https://api.openweathermap.org/data/2.5/onecall?lat=37.4419&lon=-122.143&units=imperial&appid=\(Util.apiKey(key: "open_weather_api_key"))"
            let url = URL(string: urlStr)!
            // This free weather service is unreliable - dont error to user if it fails
            let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                if let error = error {
                    Util.app().reportError(class_type: type(of: self), context: "Error loading weather", error: "\(error)", informUsers: false)
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                    Util.app().reportError(class_type: type(of: self), context: "Bad HTTP status loading weather \(response.debugDescription)", error: "not HTTP 200", informUsers: false)
                    return
                }
                
                if let data = data {
                    if let data = try? JSONDecoder().decode(WeatherData.self, from: data) {
                        self.weatherData = data
                        DispatchQueue.main.async {
                            self.notifyObservers(count: data.daily.count)
                        }
                    }
                    else {
                        Util.app().reportError(class_type: type(of: self), context: "Cannot parse weather data json", error: nil, informUsers: false)
                    }
                } else {
                    Util.app().reportError(class_type: type(of: self), context: "no weather data json", error: "no data", informUsers:  false)
                }
            })
            task.resume()
        }
    }
}
