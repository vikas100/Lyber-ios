//
//  RecordViewController.swift
//  Lyber
//
//  Created by Edward Feng on 7/2/18.
//  Copyright © 2018 Edward Feng. All rights reserved.
//

import UIKit
import CoreData
import GooglePlaces

class RecordViewController: UIViewController, GMSAutocompleteViewControllerDelegate {

    var blue = false
    var red = false
    
    var history: [Record] = []
    
    lazy var refresher: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .blue
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        return refreshControl
    }()
    
    @IBOutlet weak var blueTxt: UITextField!
    
    var blueCoord: CLLocationCoordinate2D!
    
    @IBOutlet weak var redTxt: UITextField!
    
    @IBOutlet weak var recordTable: UITableView!
    
    var redCoord: CLLocationCoordinate2D!
    
    @IBAction func pressedBlue(_ sender: UITextField) {
        let autocompleteControllerBlue = GMSAutocompleteViewController()
        autocompleteControllerBlue.delegate = self
        
        blue = true
        present(autocompleteControllerBlue, animated: true, completion: nil)
    }
    
    @IBAction func redPressed(_ sender: UITextField) {
        let autocompleteControllerRed = GMSAutocompleteViewController()
        autocompleteControllerRed.delegate = self
        
        red = true
        present(autocompleteControllerRed, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recordTable.delegate = self
        recordTable.dataSource = self
        let redResult = RecordViewController.fetchPlace(tag: "red")
        if (redResult.count != 0) {
            redTxt.text = redResult[0].name
            redCoord = CLLocationCoordinate2D(latitude: redResult[0].lat, longitude: redResult[0].lng)
        }
        let blueResult = RecordViewController.fetchPlace(tag: "blue")
        if (blueResult.count != 0) {
            blueTxt.text = blueResult[0].name
            blueCoord = CLLocationCoordinate2D(latitude: blueResult[0].lat, longitude: blueResult[0].lng)
        }
        self.recordTable.refreshControl = refresher
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        history = RecordViewController.fetchRecord()
        history.sort { (record1, record2) -> Bool in
            return record1.time_stamp?.compare(record2.time_stamp! as Date) == ComparisonResult.orderedDescending
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // GMSAutocomplet code
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        if (blue == true) {
            DispatchQueue.main.async { [weak self] in
                self?.blueTxt.text = place.name
                self?.blueCoord = place.coordinate
                RecordViewController.checkAndDelete(tag: "blue")
                let placeToSave = Place(context: PersistenceService.context)
                placeToSave.tag = "blue"
                placeToSave.name = place.name
                placeToSave.id = place.placeID
                placeToSave.lat = Double(place.coordinate.latitude)
                placeToSave.lng = Double(place.coordinate.longitude)
                PersistenceService.saveContext()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.redTxt.text = place.name
                self?.redCoord = place.coordinate
                RecordViewController.checkAndDelete(tag: "red")
                let placeToSave = Place(context: PersistenceService.context)
                placeToSave.tag = "red"
                placeToSave.name = place.name
                placeToSave.id = place.placeID
                placeToSave.lat = Double(place.coordinate.latitude)
                placeToSave.lng = Double(place.coordinate.longitude)
                PersistenceService.saveContext()
            }
        }
        blue = false
        red = false
        self.dismiss(animated: true, completion: nil)
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        red = false
        blue = false
        self.dismiss(animated: true, completion: nil)
    }
    
    // Fetching places
    static func fetchPlace(tag: String) -> [Place] {
        let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        let predicate = NSPredicate(format: "tag = %@", tag)
        fetchRequest.predicate = predicate
        var places : [Place] = []
        do {
            places = try PersistenceService.context.fetch(fetchRequest)
            
        } catch {
        }
        return places
    }
    
    // Fetching records
    static func fetchRecord() -> [Record] {
        let fetchRequest: NSFetchRequest<Record> = Record.fetchRequest()
        var records : [Record] = []
        do {
            records = try PersistenceService.context.fetch(fetchRequest)
            
        } catch {
        }
        return records
    }
    
    static func checkAndDelete(tag: String) {
        let result = fetchPlace(tag: tag)
        if (!result.isEmpty) {
            for ele in result {
                PersistenceService.context.delete(ele)
            }
        }
    }
    
    @objc
    func refreshData() {
        self.history = RecordViewController.fetchRecord()
        history.sort { (record1, record2) -> Bool in
            return record1.time_stamp?.compare(record2.time_stamp! as Date) == ComparisonResult.orderedDescending
        }
        recordTable.reloadData()
        refresher.endRefreshing()
    }

}

extension RecordViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "recordCell") as! RecordTableViewCell
        let time = history[indexPath.row].time_stamp! as Date
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateString = formatter.string(from: time)
        cell.time.text = dateString
        cell.type.text = history[indexPath.row].product
        cell.price.text = lyftPriceRange(low: Int(history[indexPath.row].price_min), high: Int(history[indexPath.row].price_max))
        cell.from.text = history[indexPath.row].dep_name
        cell.to.text = history[indexPath.row].dest_name
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}
