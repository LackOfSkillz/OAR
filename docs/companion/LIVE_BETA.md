# Universal live beta plan (OI08-12)

**Status: OWNER, not run.** It needs real clients. Mock results never stand in for it.

**Matrix:** 9 classes times their roles (Class profiles: `ClassProfiles.ROLES`), each run solo and in a group.

**Situations to cover:**
- low gold (under 1g)
- reload and logout mid-plan
- an addon conflict (Questie, TomTom, Auctionator, ElvUI installed)
- a non-English locale, if available

**Collected automatically** (AutoCheck and the outcome recorder, opt-in):
- build, class, role, level
- the pages opened
- errors
- taint lines
- the plan steps chosen
- the frame time (PerformanceStats)

`tools/read-logs.ps1` sanitises the log before it is attached.

**Pass rule:**
- no Lua errors;
- no taint;
- no feature claims for a role that couldn't be tested (that role blocks a "universal" claim);
- every failure is tracked as a task.

**Owner steps** (per character, about 10 minutes):
1. log in
2. open the Plan, What if?, Lessons and Fix problems pages
3. do one plan step
4. log out
5. say done
