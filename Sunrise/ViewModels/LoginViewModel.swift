//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveCocoa

/// The key used for storing logged in username.
let kLoggedInUsername = "LoggedInUsername"

class LoginViewModel: BaseViewModel {

    // Inputs
    let username = MutableProperty("")
    let password = MutableProperty("")
    let title = MutableProperty("")
    let firstName = MutableProperty("")
    let lastName = MutableProperty("")
    let email = MutableProperty("")
    let registrationPassword = MutableProperty("")
    let registrationPasswordConfirmation = MutableProperty("")

    // Outputs
    let isLoggedIn: MutableProperty<Bool>
    let isLoading: MutableProperty<Bool>
    let isLoginInputValid = MutableProperty(false)

    // Actions
    lazy var loginAction: Action<Void, Void, NSError> = { [unowned self] in
        return Action(enabledIf: self.isLoginInputValid, { _ in
            self.isLoading.value = true
            return self.loginUser(self.username.value, password: self.password.value)
        })
    }()

    // MARK: Lifecycle

    override init() {
        isLoggedIn = MutableProperty(AuthManager.sharedInstance.state == .CustomerToken)
        isLoading = MutableProperty(false)

        super.init()

        isLoginInputValid <~ username.producer.combineLatestWith(password.producer).map { (username, password) in
            username.characters.count > 0 && password.characters.count > 0
        }
    }

    // MARK: - Commercetools platform user log in and sign up

    private func loginUser(username: String, password: String) -> SignalProducer<Void, NSError> {
        return SignalProducer { [weak self] observer, disposable in
            AuthManager.sharedInstance.loginUser(username, password: password, completionHandler: { error in
                if let error = error {
                    observer.sendFailed(error)
                } else {
                    observer.sendCompleted()
                    // Save username to user defaults for displaying it later on in the app
                    NSUserDefaults.standardUserDefaults().setObject(username, forKey: kLoggedInUsername)
                    NSUserDefaults.standardUserDefaults().synchronize()
                }
                self?.isLoading.value = false
            })
        }
    }

    private func registerUser() -> SignalProducer<Void, NSError> {
        let username = email.value
        let password = registrationPassword.value
        let userProfile = ["email": username,
                           "password": password,
                           "firstName": firstName.value,
                           "lastName": lastName.value,
                           "title": title.value]

        return SignalProducer { [weak self] observer, disposable in
            Commercetools.Customer.signup(userProfile, result: { result in
                if let error = result.errors?.first where result.isFailure {
                    observer.sendFailed(error)
                } else {
                    self?.loginUser(username, password: password).startWithSignal { signal, signalDisposable in
                        disposable.addDisposable(signalDisposable)
                        signal.observe { event in
                            switch event {
                                case let .Failed(error):
                                    observer.sendFailed(error)
                                default:
                                    observer.sendCompleted()
                            }

                        }
                    }
                }
            })
        }
    }

}