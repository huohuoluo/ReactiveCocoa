//
//  SignalLifetimeSpec.swift
//  ReactiveCocoa
//
//  Created by Vadim Yelagin on 2015-12-13.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

class SignalLifetimeSpec: QuickSpec {
	override func spec() {
		describe("init") {
			var testScheduler: TestScheduler!

			beforeEach {
				testScheduler = TestScheduler()
			}

			it("should deallocate") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { _ in }

				expect(signal).to(beNil())
			}

			it("should deallocate even if it has an observer") {
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in }
					return signal
				}()
				expect(signal).to(beNil())
			}

			/**
			it("should deallocate even if it has an observer with retained disposable") {
				var disposable: Disposable? = nil
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in }
					disposable = signal.observe(Observer())
					return signal
				}()
				expect(signal).to(beNil())
				disposable?.dispose()
				expect(signal).to(beNil())
			}
			**/

			it("should deallocate after erroring") {
				weak var signal: Signal<AnyObject, TestError>? = Signal { observer in
					testScheduler.schedule {
						observer.sendFailed(TestError.Default)
					}
				}

				var errored = false

				signal?.observeFailed { _ in errored = true }

				expect(errored) == false
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(errored) == true
				expect(signal).to(beNil())
			}

			it("should deallocate after completing") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { observer in
					testScheduler.schedule {
						observer.sendCompleted()
					}
				}

				var completed = false

				signal?.observeCompleted { completed = true }

				expect(completed) == false
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(completed) == true
				expect(signal).to(beNil())
			}

			it("should deallocate after interrupting") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { observer in
					testScheduler.schedule {
						observer.sendInterrupted()
					}
				}

				var interrupted = false
				signal?.observeInterrupted {
					interrupted = true
				}

				expect(interrupted) == false
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(interrupted) == true
				expect(signal).to(beNil())
			}
		}

		describe("Signal.pipe") {
			it("should deallocate") {
				weak var signal = Signal<(), NoError>.pipe().0

				expect(signal).to(beNil())
			}

			it("should deallocate after erroring") {
				let testScheduler = TestScheduler()
				weak var weakSignal: Signal<(), TestError>?

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test = {
					let (signal, observer) = Signal<(), TestError>.pipe()
					weakSignal = signal
					testScheduler.schedule {
						observer.sendFailed(TestError.Default)
					}
				}
				test()

				expect(weakSignal).toNot(beNil())

				testScheduler.run()
				expect(weakSignal).to(beNil())
			}

			it("should deallocate after completing") {
				let testScheduler = TestScheduler()
				weak var weakSignal: Signal<(), TestError>?

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test = {
					let (signal, observer) = Signal<(), TestError>.pipe()
					weakSignal = signal
					testScheduler.schedule {
						observer.sendCompleted()
					}
				}
				test()

				expect(weakSignal).toNot(beNil())

				testScheduler.run()
				expect(weakSignal).to(beNil())
			}

			it("should deallocate after interrupting") {
				let testScheduler = TestScheduler()
				weak var weakSignal: Signal<(), NoError>?

				let test = {
					let (signal, observer) = Signal<(), NoError>.pipe()
					weakSignal = signal

					testScheduler.schedule {
						observer.sendInterrupted()
					}
				}

				test()
				expect(weakSignal).toNot(beNil())

				testScheduler.run()
				expect(weakSignal).to(beNil())
			}
		}

		describe("testTransform") {
			it("should deallocate") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { _ in }.testTransform()

				expect(signal).to(beNil())
			}

			it("should deallocate even if it has an observer") {
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in }.testTransform()
					signal.observe(Observer())
					return signal
				}()
				expect(signal).to(beNil())
			}

			/**
			it("should deallocate even if it has an observer with retained disposable") {
				var disposable: Disposable? = nil
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in }.testTransform()
					disposable = signal.observe(Observer())
					return signal
				}()
				expect(signal).to(beNil())
				disposable?.dispose()
				expect(signal).to(beNil())
			}
			**/
		}

		describe("observe") {
			var signal: Signal<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			var token: NSObject? = nil
			weak var weakToken: NSObject?

			func expectTokenNotDeallocated() {
				expect(weakToken).toNot(beNil())
			}

			func expectTokenDeallocated() {
				expect(weakToken).to(beNil())
			}

			beforeEach {
				let (signalTemp, observerTemp) = Signal<Int, TestError>.pipe()
				signal = signalTemp
				observer = observerTemp

				token = NSObject()
				weakToken = token

				signal.observe { [token = token] _ in
					_ = token!.description
				}
			}

			it("should deallocate observe handler when signal completes") {
				expectTokenNotDeallocated()

				observer.sendNext(1)
				expectTokenNotDeallocated()

				token = nil
				expectTokenNotDeallocated()

				observer.sendNext(2)
				expectTokenNotDeallocated()

				observer.sendCompleted()
				expectTokenDeallocated()
			}

			it("should deallocate observe handler when signal fails") {
				expectTokenNotDeallocated()

				observer.sendNext(1)
				expectTokenNotDeallocated()

				token = nil
				expectTokenNotDeallocated()

				observer.sendNext(2)
				expectTokenNotDeallocated()

				observer.sendFailed(.Default)
				expectTokenDeallocated()
			}
		}
	}
}

private extension SignalType {
	func testTransform() -> Signal<Value, Error> {
		return Signal { observer in
			return self.observe(observer.action)
		}
	}
}
