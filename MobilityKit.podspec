Pod::Spec.new do |s|
  s.name         = "MobilityKit"
  s.version      = "1.0.0"
  s.summary      = "First open source mobility detection framework for iOS"
  s.homepage     = "http://github.com/mobilitykit/mobilitykit-ios"
  s.license      = "GPL"
  s.authors      = { "Tobias Frech" => "tf@bu.do", "Thomas Fankhauser" => "tf@system8.io" }
  s.platform     = :ios, "12.0"
  s.source       = { :git => "git@github.com:mobilitykit/mobilitykit-ios.git", :tag => "v1.0.0" }
  s.source_files  = "MobilityKit/**/*.swift"
end
