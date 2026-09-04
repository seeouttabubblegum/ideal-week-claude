//
//  MainViewViewModel.swift
//  The Ideal Week
//
//  Created by Tanvir Ahmed Chowdhury on 7/4/25.
//
import FirebaseAuth
import Foundation
class MainViewViewModel: ObservableObject {
    @Published var currentUserId: String = ""
    private var handler: AuthStateDidChangeListenerHandle?
    init(){
        self.handler = Auth.auth().addStateDidChangeListener {[weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUserId = user?.uid ?? ""
            }
        }
    }
    
    public var isSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }
    
    private func removeAuthListener() {
        if let handler = handler {
            Auth.auth().removeStateDidChangeListener(handler)
            self.handler = nil
        }
    }
    
    deinit {
        removeAuthListener()
    }
}
