# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'Western-Wheelers' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Western-Wheelers
  pod "SwiftSoup"
  pod 'FBSDKCoreKit'
  pod 'FBSDKLoginKit'
  pod 'FBSDKShareKit'

  post_install do |installer|
    installer.generated_projects.each do |project|
      project.targets.each do |target|
          target.build_configurations.each do |config|
              config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
           end
      end
    end
  end

  target 'Western-WheelersTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'Western-WheelersUITests' do
    # Pods for testing
  end

end
