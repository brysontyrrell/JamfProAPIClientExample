//
//  Extensions+Components.Schemas.swift
//  JamfProAPIClientExample
//
//  Created by Bryson Tyrrell on 8/28/24.
//

import Foundation

extension Components.Schemas.ComputerInventory: Identifiable, Comparable {
    static func < (lhs: Components.Schemas.ComputerInventory, rhs: Components.Schemas.ComputerInventory) -> Bool {
        // 'id' is guaranteed to exist in a ComuterInventory response
        // In a future version of Jamf Pro 'id' may no longer be a string integer
        let lhsAsInt = Int(lhs.id!)
        let rhsAsInt = Int(rhs.id!)
        
        if (lhsAsInt != nil), (rhsAsInt != nil) {
            return lhsAsInt! < rhsAsInt!
        } else {
            return lhs.id! < rhs.id!
        }
    }
}
