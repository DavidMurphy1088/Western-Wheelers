import Foundation
import Combine
import SwiftUI
import os.log

class Rides : ObservableObject {
    private static var inst: Rides? = nil
    
    @Published var rides:[Ride] = []//()
    @Published var publishedTotalRides: Int? = nil
    @Published var lastLoadDate:Date?
    @Published var loadCounts = 0

    public let rideLoadedCount = PassthroughSubject<Int?, Never>()

    let ridesLoader = RidesLoader()
    let weatherLoader = WeatherAPI()
    let statsLoader = StatsLoader()

    var notifiedRidesLoaded:AnyCancellable? = nil
    var notifiedWeatherLoaded:AnyCancellable? = nil
    var imageLoadedCancel = [AnyCancellable]()

    var rideCount: Int? = nil;
    var weatherImages = [String: ImageLoader]()
    var weatherDayData = [Date: WeatherAPI.DayWeather]()
    var weatherApplied = false

    // other (than View) classes can subsribe to this to be notified of data changes. Views can use the published data state
    //public let data_was_loaded = PassthroughSubject<Rides, Never>()

    static func instance() -> Rides {
        if Rides.inst == nil {
            Rides.inst = Rides()
        }
        return Rides.inst!
    }
    
    func setRideList(ridesLoaded: [Ride]) {
        DispatchQueue.main.async {
            Rides.inst?.rides = ridesLoaded
            Rides.inst?.publishedTotalRides = ridesLoaded.count
            Rides.inst?.lastLoadDate = Date()
            Rides.inst?.loadCounts += 1
            self.rideLoadedCount.send(ridesLoaded.count)
        }
    }
    
    // apply weather date for the ride's day if we have weather details
    func applyWeather() {
        var weather_dates = Array(weatherDayData.keys)
        weather_dates.sort()
        var applied = 0
        for ride in rides {
            for weather_date in weather_dates {
                //Rides.show_date(d: weather_date, msg: "apply weather")
                // the weather date is the date/time they are forecasting the weather for - at this time its noon daily. (i.e. not the time they made the forecast)
                let diff = weather_date.timeIntervalSinceReferenceDate - ride.dateTime.timeIntervalSinceReferenceDate
                let hours_diff = Double(diff/(60 * 60)) // hours diff ride start vs time forecasted
                //is forecast between ride start and end?
                if hours_diff >= 0 && hours_diff < Ride.LONGEST_RIDE_IN_HOURS {
                    ride.weather_date = weather_date
                    let day_weather = weatherDayData[weather_date]
                    ride.weather_day = day_weather!.temp.day
                    ride.weather_day_celsius = ((ride.weather_day ?? 0) - 32.0) * (5.0 / 9.0)
                    ride.weather_max = day_weather!.temp.max
                    ride.weather_min = day_weather!.temp.min
                    ride.weather_min_celsius = ((ride.weather_min ?? 0) - 32.0) * (5.0 / 9.0)
                    ride.weather_pressure = day_weather!.pressure
                    ride.weather_description = day_weather!.weather[0].description
                    ride.weather_main = day_weather!.weather[0].main
                    if ride.weather_main != nil {
                        ride.weatherDisp = "  \(ride.weather_main!) \(String(format: "%.0f", ride.weather_day!))°  "
                        applied += 1
                    }
                    break
                }
            }
            if ride.weatherDisp == nil {
                if ride.isEveningRide() {
                    ride.weatherDisp = " Evening "
                }
            }
            
        }
    }
    
    //load weather dates and icon image from JSON for each day and dictionary of icon->image
    func loadWeather() {
        // build weather image loaders into a dictionary by icon name, clear, cloudy.. etc
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // RSS dates are in UTC
        formatter.dateFormat = "yyyy MM dd HH:mm:ss"
        if let data = weatherLoader.weatherData {
            for day in data.daily {
                let day_date_utc = Date(timeIntervalSince1970: TimeInterval(day.dt))
                weatherDayData[day_date_utc] = day
                //let icon = day.weather[0].icon
            }
        }
    }
    
    func startRideLoader() {
        let serialQueue = DispatchQueue(label: "ride.loader")

        serialQueue.async {
            let waitTimeSeconds = 30 * 60 //1/2 hour
            //let waitTimeSeconds = 5 //1/2 hour
            while true {
                self.loadRides()
                sleep(UInt32(waitTimeSeconds)) //dont remove sleep
            }
        }
    }
    
    func loadRides() {
        //cannot tell whether rides or weather will load first
        self.notifiedRidesLoaded = self.rideLoadedCount.sink(receiveValue: { value in
            self.rideCount = value
            if !self.weatherApplied {
                self.applyWeather()
            }

            DispatchQueue.main.async { // publishing cannot come from background thread
                self.publishedTotalRides = self.rideCount
                //self.data_was_loaded.send(self)
            }
        })

        self.notifiedWeatherLoaded = weatherLoader.weatherDaysLoaded.sink(receiveValue: { value in
            self.loadWeather()
            if self.rideCount != nil {
                self.applyWeather()
                self.weatherApplied = true
            }
        })

        weatherLoader.load()
        WAApi.instance().loadRides() 
    }
    
    func getRidesByLevel(level: String?) -> [Ride] {
        var ride_list = [Ride]()
        for ride in rides {
            if level == nil || ride.getLevels().contains(String(level!)) {
                ride_list.append(ride)
            }
        }
        return ride_list
    }
    
    func getRidesByRideId(rid: String) -> Ride? {
        for ride in rides {
            if ride.rideId == rid {
                return ride
            }
        }
        return nil
    }
    
    func getRidesByDescription(search_desc: String) -> [Ride] {
        var ride_list = [Ride]()
        let look_for = search_desc.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for ride in rides {
            if var title = ride.titleFull {
                title = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if title.contains(look_for) {
                    ride_list.append(ride)
                }
            }
        }
        return ride_list
    }

}
