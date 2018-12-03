//
//  ViewController.swift
//  MapKitSA
//
//  Created by David on 02/09/2018.
//  Copyright © 2018 David. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {
    
    let locationManager = CLLocationManager()
    let regionInMeters: Double = 10000
    var previousLocation: CLLocation?
    let geoCoder = CLGeocoder()
    var directionsArray: [MKDirections] = []
    
    lazy var goButton: UIButton = { [unowned self] in
        let but = UIButton(type: .system)
        but.translatesAutoresizingMaskIntoConstraints = false
        but.backgroundColor = .red
        but.setTitle("Go!", for: .normal)
        but.setTitleColor(.white, for: .normal)
        but.layer.cornerRadius = 20
        but.addTarget(self, action: #selector(handleGoButtonTap), for: .touchUpInside)
        return but
    }()
    
    let pinImageView: UIImageView = {
        let iv = UIImageView(image: #imageLiteral(resourceName: "pin"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    lazy var mapView: MKMapView = { [unowned self] in
        let mv = MKMapView()
        mv.delegate = self
        mv.translatesAutoresizingMaskIntoConstraints = false
        return mv
    }()
    
    let locationLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.textAlignment = .center
        lbl.backgroundColor = .white
        lbl.font = UIFont.systemFont(ofSize: 20)
        lbl.text = "Label text"
        return lbl
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        
        view.addSubview(mapView)
        view.addSubview(locationLabel)
        view.addSubview(pinImageView)
        view.addSubview(goButton)
        
        let constraints = [
        
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            locationLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            locationLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            locationLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            locationLabel.heightAnchor.constraint(equalToConstant: 50),
            
            pinImageView.widthAnchor.constraint(equalToConstant: 40),
            pinImageView.heightAnchor.constraint(equalToConstant: 40),
            pinImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            
            goButton.heightAnchor.constraint(equalToConstant: 40),
            goButton.widthAnchor.constraint(equalToConstant: 40),
            goButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            goButton.bottomAnchor.constraint(equalTo: locationLabel.topAnchor)
        ]
        
        NSLayoutConstraint.activate(constraints)

        checkLocationServices()
    }
    
    @objc fileprivate func handleGoButtonTap() {
        getDirections()
    }
    
    fileprivate func getDirections() {
        guard let userLocation = locationManager.location?.coordinate else { return }
        
        let request = createDirectionsRequest(from: userLocation)
        let directions = MKDirections(request: request)
        resetMapView(withNewDirections: directions)
        
        directions.calculate { [unowned self] (response, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard let response = response else { return }
            
            for route in response.routes {
                self.mapView.add(route.polyline)
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
            }
        }
    }
    
    fileprivate func createDirectionsRequest(from coordinate: CLLocationCoordinate2D) -> MKDirectionsRequest {
        
        let destinationCoordinate = getCenterLocation(forMapView: mapView).coordinate
        let startingLocation = MKPlacemark(coordinate: coordinate)
        let destination = MKPlacemark(coordinate: destinationCoordinate)
        
        let request = MKDirectionsRequest()
        request.source = MKMapItem(placemark: startingLocation)
        request.destination = MKMapItem(placemark: destination)
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        return request
    }
    
    fileprivate func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    fileprivate func centerViewOnUserLocation() {
        if let userLocation = locationManager.location?.coordinate {
            let region = MKCoordinateRegion(center: userLocation, span: MKCoordinateSpan(latitudeDelta: regionInMeters, longitudeDelta: regionInMeters))
            mapView.setRegion(region, animated: true)
        }
    }
    
    fileprivate func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorisation()
        } else {
            // Show alert telling the user they have their location services dispabled
        }
    }
    
    fileprivate func checkLocationAuthorisation() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            break
        case .restricted:
            break
        case .denied:
            break
        case .authorizedAlways:
            break
        case .authorizedWhenInUse:
            startTrackingUserLocation()
        }
    }

    fileprivate func startTrackingUserLocation() {
        mapView.showsUserLocation = true
        centerViewOnUserLocation()
        locationManager.startUpdatingLocation()
        previousLocation = getCenterLocation(forMapView: mapView)
    }
    
    fileprivate func getCenterLocation(forMapView mapView: MKMapView) -> CLLocation {
        let lat = mapView.centerCoordinate.latitude
        let long = mapView.centerCoordinate.longitude
        
        return CLLocation(latitude: lat, longitude: long)
    }
    
    fileprivate func resetMapView(withNewDirections newDirections: MKDirections) {
        mapView.removeOverlays(mapView.overlays)
        directionsArray.forEach { $0.cancel() }
        directionsArray.removeAll()
        directionsArray.append(newDirections)
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay as! MKPolyline)
        renderer.strokeColor = .blue
        
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        let center = getCenterLocation(forMapView: mapView)
        
        guard let previousLocation = self.previousLocation, center.distance(from: previousLocation) > 50 else { return }
        self.previousLocation = getCenterLocation(forMapView: mapView)
        
        geoCoder.cancelGeocode()
        
        geoCoder.reverseGeocodeLocation(center) { [weak self] (placemarks, error) in
            guard let strongSelf = self else { return }
            
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard let placemark = placemarks?.first else { return }
            
            let streetNumber = placemark.subThoroughfare ?? ""
            let streetName = placemark.thoroughfare ?? ""
            
            DispatchQueue.main.async {
                strongSelf.locationLabel.text = "\(streetNumber) \(streetName)"
            }
        }
    }
    
}


extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorisation()
    }
}
