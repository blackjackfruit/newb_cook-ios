//
//  Authentication.swift
//  NewbCook
//
//  Created by iury on 9/15/23.
//

import Foundation

protocol Authentication {
    func validateLoginCredentials(using transmitLoginCredentials: TransmitLoginCredentials, completion: @escaping (AppError?)-> Void)
    func invalidateUserCredentials()
}
