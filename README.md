# README

## Tasks
- [x] Make a list of assumptions
- [ ] Generate random test data for different cases
  - [ ] Random events
  - [ ] User has no availability
  - [ ] User has unevenly stacked days
  - [ ] User has no events on one of the days
  - [ ] User has a day where two of their existing meetings overlap

## Assumptions
- Users will not be available from 8PM - 8AM, which is when they sleep
- Users will not be available on Saturday and Sunday. Work/life balance!

## Test Data

* Case: generate random events
```
rake 'ics:generate`
```

* Case: User has no availability

* Case: User has availability on the next closest day, 
        but there is another day after that where they are free
