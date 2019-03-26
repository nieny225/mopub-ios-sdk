//
//  AdapterVersionsMenuDataSource.swift
//
//  Copyright 2018-2019 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

import UIKit
import MoPub

class AdapterVersionsMenuDataSource {
    // MARK: - Properties
    
    /**
     Alphabetically sorted adapter names.
     */
    private var adapterNames: [String] = []
    
    /**
     Set of adapter names that are currently in an expanded state.
     */
    private var expandedAdapters: Set<String> = Set<String>()
    
    // MARK: - Adapter Cell Retrieval
    
    /**
     Registers and retrieves a reusable instance of a `CollapsibleAdapterInfoTableViewCell`.
     - Parameter tableView: Table View rendering the cell.
     - Returns: A reusable `CollapsibleAdapterInfoTableViewCell` instance.
     */
    func adapterMenuCell(inTableView tableView: UITableView) -> CollapsibleAdapterInfoTableViewCell {
        let adapterCellReuseIdentifier: String = "CollapsibleAdapterInfoTableViewCell"
        
        var cell = tableView.dequeueReusableCell(withIdentifier: adapterCellReuseIdentifier) as? CollapsibleAdapterInfoTableViewCell
        if cell == nil {
            tableView.register(UINib(nibName: adapterCellReuseIdentifier, bundle: nil), forCellReuseIdentifier: adapterCellReuseIdentifier)
            cell = tableView.dequeueReusableCell(withIdentifier: adapterCellReuseIdentifier) as? CollapsibleAdapterInfoTableViewCell
        }
        
        return cell!
    }
}

extension AdapterVersionsMenuDataSource: MenuDisplayable {
    /**
     Number of menu items available
     */
    var count: Int {
        // There will always be at least one item.
        return max(adapterNames.count, 1)
    }
    
    /**
     Human-readable title for the menu grouping
     */
    var title: String {
        return "Adapters"
    }
    
    /**
     Provides the rendered cell for the menu item
     - Parameter index: Menu item index assumed to be in bounds
     - Parameter tableView: `UITableView` that will render the cell
     - Returns: A configured `UITableViewCell`
     */
    func cell(forItem index: Int, inTableView tableView: UITableView) -> UITableViewCell {
        let cell: CollapsibleAdapterInfoTableViewCell = adapterMenuCell(inTableView: tableView)
        
        // There are no adapters initialized.
        guard adapterNames.count > 0 else {
            cell.titleLabel.text = "No adapters initialized"
            return cell
        }
        
        // There exist some initialized adapters
        let name: String = adapterNames[index]
        guard let adapter: MPAdapterConfiguration = MoPub.sharedInstance().adapterConfigurationNamed(name) else {
            cell.update(title: name)
            return cell
        }
        
        let isCollapsed: Bool = !expandedAdapters.contains(name)
        cell.update(adapterName: name , info: adapter, isCollapsed: isCollapsed)
        return cell
    }
    
    /**
     Query if the menu item is selectable
     - Parameter index: Menu item index assumed to be in bounds
     - Parameter tableView: `UITableView` that rendered the item
     - Returns: `true` if selectable; `false` otherwise
     */
    func canSelect(itemAt index: Int, inTableView tableView: UITableView) -> Bool {
        // Selection is only valid if there are adapters present.
        return (adapterNames.count > 0)
    }
    
    /**
     Performs an optional selection action for the menu item
     - Parameter indexPath: Menu item indexPath assumed to be in bounds
     - Parameter tableView: `UITableView` that rendered the item
     - Parameter viewController: Presenting view controller
     - Returns: `true` if the menu should collapse when selected; `false` otherwise.
     */
    func didSelect(itemAt indexPath: IndexPath, inTableView tableView: UITableView, presentFrom viewController: UIViewController) -> Bool {
        // Verify that there are adapters present
        guard adapterNames.count > 0 && indexPath.row < adapterNames.count else {
            return false
        }
        
        // Toggle the expanded state for the adapter
        let name: String = adapterNames[indexPath.row]
        if expandedAdapters.contains(name) {
            expandedAdapters.remove(name)
        }
        else {
            expandedAdapters.insert(name)
        }
        
        // Notify the table view that it needs to refresh the layout for the selected cell.
        tableView.beginUpdates()
        tableView.reloadRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()
        return false
    }
    
    /**
     Updates the data source if needed.
     */
    func updateIfNeeded() -> Swift.Void {
        adapterNames = MoPub.sharedInstance().availableAdapterClassNames()?.sorted() ?? []
    }
}
