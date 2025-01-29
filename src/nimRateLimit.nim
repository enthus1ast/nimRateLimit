## Generic rate limit code
## does not raise
{.push raises: [].}
import tables, times, locks, os

type
  Ident* = tuple[ressource, who: string]
  RateLimiter = object
    tab: CountTable[Ident]
  ThreadOptions = object
    prl: ptr RateLimiter
    sleepTimeout: int
    decrAmount: int

var rlLock: Lock
var dt: Thread[ThreadOptions]

proc newRateLimiter*(): RateLimiter =
 result = RateLimiter()

proc add*(rl: var RateLimiter, ident: Ident) =
  {.cast(gcsafe).}:
    rlLock.withLock:
      rl.tab.inc(ident)

proc isAllowed*(rl: RateLimiter, ident: Ident, maxTries = 3): bool =
  {.cast(gcsafe).}:
    rlLock.withLock:
      return rl.tab[ident] <= maxTries

proc decr(rl: var RateLimiter, decrementAmount = -1 ) =
  {.cast(gcsafe).}:
    rlLock.withLock:
      let ctab = rl.tab 
      for key in ctab.keys:
        rl.tab.inc(key, val = -1 * abs(decrementAmount) )
        if rl.tab[key] <= 0:
          when not defined(release):
            echo "DEL: ", key
          rl.tab.del(key)

proc decrementerThread(to: ThreadOptions) {.thread.} =
  while true:
    when not defined(release):
      echo ".", to.prl[]
    sleep to.sleepTimeout
    to.prl[].decr(to.decrAmount)

proc startDecrementerThread*(rl: RateLimiter, sleepTimeout = 1_000, decrAmount = 1): bool =
  ## If returns true if the thread could be started, in case of an error false is returned.
  try:
    createThread(dt, decrementerThread, ThreadOptions(prl: addr rl, sleepTimeout: sleepTimeout, decrAmount: decrAmount))
    return true
  except:
    return false


when isMainModule:
  var rl = RateLimiter()
  let ident: Ident = ("/admin/login", "192.168.1.123")
  let ident2: Ident = ("/admin/login", "141.168.1.123")
  assert true == rl.startDecrementerThread()
  rl.add ident
  for idx in 0..10:
    rl.add ident2
  echo rl
  rl.add ident
  echo rl.isAllowed(ident)
  rl.add ident
  echo rl.isAllowed(ident)
  rl.decr
  rl.decr
  rl.decr
  rl.decr
  rl.add ident

  echo rl
  import random
  while true:
    sleep (rand(3000))
    rl.add ident
    echo rl
    echo rl.isAllowed(ident)


