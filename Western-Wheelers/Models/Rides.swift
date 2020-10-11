import Foundation
import Combine
import SwiftUI
import os.log

class Rides : ObservableObject {
    private static var inst: Rides? = nil
    
    //published data for views
    @Published var rides:[Ride] = []
    @Published var publishedTotalRides: Int? = nil
    @Published var lastLoadDate:Date?
    @Published var rideListLoadsCount = 0
    
    //subject for subscribers
    public let ridesListSubject = PassthroughSubject<[Ride]?, Never>()
    //public let weatherLoadedSubject = PassthroughSubject<Bool, Never>()

    let ridesLoader = RidesLoader()
    let weatherLoader = WeatherAPI()
    let statsLoader = StatsLoader()

    var notifiedRidesLoaded:AnyCancellable? = nil
    var notifiedWeatherLoaded:AnyCancellable? = nil
    var imageLoadedCancel = [AnyCancellable]()

    var weatherImages = [String: ImageLoader]()
    var weatherDayData = [Date: WeatherAPI.DayWeather]()
    var weatherLoaded = false
    var ridesLoaded = false

    static func instance() -> Rides {
        if Rides.inst == nil {
            Rides.inst = Rides()
        }
        return Rides.inst!
    }
    
    func startLoader() {
        let serialQueue = DispatchQueue(label: "ride.loader")
        serialQueue.async {
            let waitTimeMinutes = 30
            let waitTimeSeconds = waitTimeMinutes * 60
            while true {
                Rides.inst!.loadRides()
                sleep(UInt32(waitTimeSeconds)) //dont remove sleep
            }
        }
    }
    
    func setRideList(rideList: [Ride]) {
        if self.weatherLoaded {
            self.applyWeather(rideList: rideList)
        }
        ridesLoaded = true
        DispatchQueue.main.async {
            Rides.inst?.rides = rideList
            Rides.inst?.publishedTotalRides = rideList.count
            Rides.inst?.lastLoadDate = Date()
            Rides.inst?.rideListLoadsCount += 1
            self.ridesListSubject.send(rideList)
        }
    }
        
    func loadRides() {
        //cannot know whether rides or weather will load first
        self.notifiedWeatherLoaded = weatherLoader.weatherDaysLoaded.sink(receiveValue: { value in
            self.buildWeatherData()
            self.weatherLoaded = true
            if self.ridesLoaded {
                self.applyWeather(rideList: self.rides)
                self.ridesListSubject.send(self.rides)
            }
        })
        
        weatherLoaded = false
        ridesLoaded = false
        WAApi.instance().loadRides()
        weatherLoader.load()
    }
    
    func getRidesByRideId(rid: String) -> Ride? {
        for ride in rides {
            if ride.rideId == rid {
                return ride
            }
        }
        return nil
    }
    
    // apply weather date for the ride's day if we have weather details
    func applyWeather(rideList:[Ride]) {
        var weather_dates = Array(weatherDayData.keys)
        weather_dates.sort()
        var applied = 0
        for ride in rideList {
            for weather_date in weather_dates {
                //Rides.show_date(d: weather_date, msg: "apply weather")
                // the weather date is the date/time they are forecasting the weather for - at this time its noon daily. (i.e. not the time they made the forecast)
                let diff = weather_date.timeIntervalSinceReferenceDate - ride.dateTime.timeIntervalSinceReferenceDate
                let hours_diff = Double(diff/(60 * 60)) // hours diff ride start vs time forecasted
                //is forecast between ride start and end?
                if hours_diff >= 0 && hours_diff < Ride.LONGEST_RIDE_IN_HOURS {
                    let dayWeather = weatherDayData[weather_date]
                    //let weather_day = day_weather!.temp.day
                    let weatherMax = dayWeather!.temp.max
                    let weatherDesc = dayWeather!.weather[0].main
                    //ride.weatherDisp = "  \(weatherDesc) \(String(format: "%.0f", weather_day))° \(String(format: "%.0f", weather_max))°  "
                    //max appears to be closer to weather underground day max
                    ride.weatherDisp = "  \(weatherDesc) \(String(format: "%.0f", weatherMax))° "
                    applied += 1
                    break
                }
            }
            if ride.weatherDisp == nil {
                if ride.isEveningRide() {
                    ride.weatherDisp = " Evening "
                }
            }
        }
        //self.weatherLoadedSubject.send(true)
    }
    
    //load weather dates and icon image from JSON for each day and dictionary of icon->image
    func buildWeatherData() {
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

}
