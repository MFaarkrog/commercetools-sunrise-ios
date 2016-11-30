import Foundation
import ReactiveSwift
import ReactiveObjC
import Result

extension UITextField {
    func signalProducer() -> SignalProducer<String, NoError> {
        return self.rac_textSignal().toSignalProducer()
        .map { $0 as! String }
        .flatMapError { _ in return SignalProducer<String, NoError>.empty }
    }
}

extension UITableViewCell {
    func prepareForReuseSignalProducer() -> SignalProducer<Void, NoError> {
        return self.rac_prepareForReuseSignal.toSignalProducer()
        .map { _ in () }
        .flatMapError { _ in return SignalProducer<Void, NoError>.empty }
    }
}

extension SignalProtocol {
    /// Turns each value into an Optional.
    fileprivate func optionalize() -> Signal<Value?, Error> {
        return map(Optional.init)
    }
}

extension SignalProducerProtocol {
    /// Turns each value into an Optional.
    fileprivate func optionalize() -> SignalProducer<Value?, Error> {
        return lift { $0.optionalize() }
    }
}

extension RACDisposable: Disposable {}

extension ImmediateScheduler {
    /// Create `RACScheduler` that performs actions instantly.
    ///
    /// - returns: `RACScheduler` that instantly performs actions.
    public func toRACScheduler() -> RACScheduler {
        return RACScheduler.immediate()
    }
}

extension UIScheduler {
    /// Create `RACScheduler` for `UIScheduler`
    ///
    /// - returns: `RACScheduler` instance that queues events on main thread.
    public func toRACScheduler() -> RACScheduler {
        return RACScheduler.mainThread()
    }
}

extension QueueScheduler {
    /// Create `RACScheduler` backed with own queue
    ///
    /// - returns: Instance `RACScheduler` that queues events on
    ///            `QueueScheduler`'s queue.
    public func toRACScheduler() -> RACScheduler {
        return RACTargetQueueScheduler(name: "org.reactivecocoa.ReactiveObjCBridge.QueueScheduler.toRACScheduler()", targetQueue: queue)
    }
}

private func defaultNSError(_ message: String, file: String, line: Int) -> NSError {
    return Result<(), NSError>.error(message, file: file, line: line)
}

extension RACSignal {
    /// Create a `SignalProducer` which will subscribe to the receiver once for
    /// each invocation of `start()`.
    ///
    /// - parameters:
    ///   - file: Current file name.
    ///   - line: Current line in file.
    ///
    /// - returns: Signal producer created from `self`.
    public func toSignalProducer(file: String = #file, line: Int = #line) -> SignalProducer<Any?, NSError> {
        return SignalProducer { observer, disposable in
            let next = { obj in
                observer.send(value: obj)
            }
            
            let failed: (_ nsError: Swift.Error?) -> () = {
                observer.send(error: ($0 as? NSError) ?? defaultNSError("Nil RACSignal error", file: file, line: line))
            }
            
            let completed = {
                observer.sendCompleted()
            }
            
            disposable += self.subscribeNext(next, error: failed, completed: completed)
        }
    }
}

extension SignalProducerProtocol {
    /// Create a `RACSignal` that will `start()` the producer once for each
    /// subscription.
    ///
    /// - note: Any `interrupted` events will be silently discarded.
    ///
    /// - returns: `RACSignal` instantiated from `self`.
    public func toRACSignal() -> RACSignal {
        return RACSignal.createSignal { subscriber in
            let selfDisposable = self.start { event in
                switch event {
                case let .value(value):
                    subscriber.sendNext(value)
                case let .failed(error):
                    subscriber.sendError(error)
                case .completed:
                    subscriber.sendCompleted()
                case .interrupted:
                    break
                }
            }
            
            return RACDisposable {
                selfDisposable.dispose()
            }
        }
    }
}

extension SignalProtocol {
    /// Create a `RACSignal` that will observe the given signal.
    ///
    /// - note: Any `interrupted` events will be silently discarded.
    ///
    /// - returns: `RACSignal` instantiated from `self`.
    public func toRACSignal() -> RACSignal {
        return RACSignal.createSignal { subscriber in
            let selfDisposable = self.observe { event in
                switch event {
                case let .value(value):
                    subscriber.sendNext(value)
                case let .failed(error):
                    subscriber.sendError(error)
                case .completed:
                    subscriber.sendCompleted()
                case .interrupted:
                    break
                }
            }
            
            return RACDisposable {
                selfDisposable?.dispose()
            }
        }
    }
}

// MARK: -

// FIXME: Reintroduce `RACCommand.toAction` when compiler no longer segfault
//        on extensions to parameterized ObjC classes.
/**
 extension RACCommand {
	/// Creates an Action that will execute the receiver.
	///
	/// - note: The returned Action will not necessarily be marked as executing
	///         when the command is. However, the reverse is always true: the
	///         RACCommand will always be marked as executing when the action
	///         is.
	///
	/// - parameters:
	///   - file: Current file name.
	///   - line: Current line in file.
	///
	/// - returns: Action created from `self`.
	public func toAction(file: String = #file, line: Int = #line) -> Action<Any?, Any?, NSError> {
 let enabledProperty = MutableProperty(true)
 
 enabledProperty <~ self.enabled.toSignalProducer()
 .map { $0 as! Bool }
 .flatMapError { _ in SignalProducer<Bool, NoError>(value: false) }
 
 return Action(enabledIf: enabledProperty) { input -> SignalProducer<Any?, NSError> in
 let executionSignal = RACSignal.`defer` {
 return self.execute(input)
 }
 **/

extension ActionProtocol {
    fileprivate var isCommandEnabled: RACSignal {
        return self.isEnabled.producer
            .map { $0 as NSNumber }
            .toRACSignal()
    }
}

/// Creates an Action that will execute the receiver.
///
/// - note: The returned Action will not necessarily be marked as executing
///         when the command is. However, the reverse is always true: the
///         RACCommand will always be marked as executing when the action
///         is.
///
/// - parameters:
///   - file: Current file name.
///   - line: Current line in file.
///
/// - returns: Action created from `self`.
public func bridgedAction<Input>(from command: RACCommand<Input>, file: String = #file, line: Int = #line) -> Action<Any?, Any?, NSError> {
    let command = command as! RACCommand<AnyObject>
    let enabledProperty = MutableProperty(true)
    
    enabledProperty <~ command.enabled.toSignalProducer()
        .map { $0 as! Bool }
        .flatMapError { _ in SignalProducer<Bool, NoError>(value: false) }
    
    return Action(enabledIf: enabledProperty) { input -> SignalProducer<Any?, NSError> in
        let executionSignal = RACSignal.`defer` {
            return command.execute(input as AnyObject?)
        }
        
        return executionSignal.toSignalProducer(file: file, line: line)
    }
}

extension ActionProtocol where Input: AnyObject {
    /// Creates a RACCommand that will execute the action.
    ///
    /// - note: The returned command will not necessarily be marked as executing
    ///         when the action is. However, the reverse is always true: the Action
    ///         will always be marked as executing when the RACCommand is.
    ///
    /// - returns: `RACCommand` with bound action.
    public func toRACCommand() -> RACCommand<Input> {
        return RACCommand<Input>(enabled: action.isCommandEnabled) { input -> RACSignal in
            return self
                .apply(input!)
                .toRACSignal()
        }
    }
}

extension ActionProtocol where Input: OptionalProtocol, Input.Wrapped: AnyObject {
    /// Creates a RACCommand that will execute the action.
    ///
    /// - note: The returned command will not necessarily be marked as executing
    ///         when the action is. However, the reverse is always true: the Action
    ///         will always be marked as executing when the RACCommand is.
    ///
    /// - returns: `RACCommand` with bound action.
    public func toRACCommand() -> RACCommand<Input.Wrapped> {
        return RACCommand<Input.Wrapped>(enabled: action.isCommandEnabled) { input -> RACSignal in
            return self
                .apply(Input(reconstructing: input))
                .toRACSignal()
        }
    }
}
