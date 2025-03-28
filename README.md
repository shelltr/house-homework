# README

## How to Install
1. Run the following
```bashrc
docker-compose build
docker-compose up
```
Note: Dockerfile.dev & docker-compose.yml are for development purposes

2. Go to http://0.0.0.0:3000
* Or whatever link you get after running the above commands

## How to query
* Query Brady
http://127.0.0.1:3000/?client_id=company_1&agent_id=deandre&start_time=2025-03-29&end_time=2025-04-03&with_suggestions=true
* Available params
  * agent_id
  * client_id (does nothing)
  * start_time (MUST be in year-month-date) format
  * end_time (MUST be in year-month-date) format
  * with_suggestions (must be true)


## Tasks
- [x] Make a list of assumptions
- [x] Generate random test data for different cases
  - [x] Random events - brady.ics
      * Randomly generates events - just a good base for
          us to test against
  - [x] User has no availability
  - [x] User has unevenly stacked days
        One of their days is completely free
  - [x] User has no events on one of the days
  - [x] User has a day where two of their existing meetings overlap
  - [ ] User's calendar has a different timezone (default is Pacific)
  - [ ] User's calendar + Company calendar have a different timezone
  - [ ] User needs meetings that are 2 hours (default is an hour)
  - [ ] User has calendar events that are multiple days long
  - [ ] User wants more padding between events
- [x] Support suggestions
  - [ ] Support further sorting -- if both days are equal, sort them by
        which one has more free time
- [x] Support client_ids
  - [x] This would be a second calendar that multiple employees from
        the same company would share
- [ ] Unit tests
  - [ ] Need coverage for everything

## Assumptions
- Users will not be available from 8PM - 8AM, which is when they sleep
- Users will not be available on Saturday and Sunday. Work/life balance!
- Users do not want to schedule meetings at random times (ex: 8:07, instead it should be anchored to the closest next time interval)

## Test Data
* Test data is available under ./data/ as `.ics` files.

## Notes
* The *_availability_calendar.ics availability dates are just for
manual testing. They don't test the actual gaps for when the day starts, just when we called 'rake ics:generate_open[nathan_overlapping]`, etc.
