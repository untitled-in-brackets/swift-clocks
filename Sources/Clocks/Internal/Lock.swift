#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(Android)
  import Android
#elseif canImport(wasi_pthread)
  import wasi_pthread
#endif

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android) || canImport(wasi_pthread)
  class PThreadLock: @unchecked Sendable {
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>

    init(recursive: Bool = false) {
      let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
      self.mutex = mutex
      var attributes = pthread_mutexattr_t()
      pthread_mutexattr_init(&attributes)
      if recursive {
        pthread_mutexattr_settype(&attributes, Int32(PTHREAD_MUTEX_RECURSIVE))
      }
      pthread_mutex_init(mutex, &attributes)
      pthread_mutexattr_destroy(&attributes)
    }

    deinit {
      pthread_mutex_destroy(mutex)
      mutex.deallocate()
    }

    func lock() {
      pthread_mutex_lock(mutex)
    }

    func unlock() {
      pthread_mutex_unlock(mutex)
    }

    @discardableResult
    func sync<R>(operation: () -> R) -> R {
      self.lock()
      defer { self.unlock() }
      return operation()
    }
  }

  typealias Lock = PThreadLock

  final class RecursiveLock: PThreadLock, @unchecked Sendable {
    init() {
      super.init(recursive: true)
    }
  }
#elseif os(WASI)
  final class Lock: @unchecked Sendable {
    func lock() {}

    func unlock() {}

    @discardableResult
    func sync<R>(operation: () -> R) -> R {
      operation()
    }
  }

  typealias RecursiveLock = Lock
#elseif canImport(WinSDK)
  import WinSDK

  final class WindowsLock: @unchecked Sendable {
    private let criticalSection: UnsafeMutablePointer<CRITICAL_SECTION>

    init() {
      let criticalSection = UnsafeMutablePointer<CRITICAL_SECTION>.allocate(capacity: 1)
      self.criticalSection = criticalSection
      InitializeCriticalSection(criticalSection)
    }

    deinit {
      DeleteCriticalSection(criticalSection)
      criticalSection.deallocate()
    }

    func lock() {
      EnterCriticalSection(criticalSection)
    }

    func unlock() {
      LeaveCriticalSection(criticalSection)
    }

    @discardableResult
    func sync<R>(operation: () -> R) -> R {
      self.lock()
      defer { self.unlock() }
      return operation()
    }
  }

  typealias Lock = WindowsLock
  typealias RecursiveLock = WindowsLock
#else
  #error("Locks are unsupported on this platform")
#endif
