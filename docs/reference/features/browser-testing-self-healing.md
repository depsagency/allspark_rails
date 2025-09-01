# Browser Testing & Self-Healing Implementation Plan

## Problem Analysis

### Current Pain Points
1. **Manual Error Discovery Cycle**
   - Claude Code implements a feature
   - User visits the page and encounters an error
   - User reports error back to Claude
   - Claude fixes the error
   - Cycle repeats 3-5 times per feature
   - Each cycle involves context switching and delays

2. **Limited Visibility**
   - Claude cannot see JavaScript console errors
   - No access to browser network tab
   - Cannot observe actual page rendering
   - Missing context from Docker container logs
   - No correlation between browser errors and server logs

3. **Incomplete Testing**
   - Unit tests don't catch integration issues
   - System tests exist but aren't run automatically by Claude
   - No easy way to verify end-to-end functionality
   - Missing user journey validation

### Root Cause Analysis
The fundamental issue is that Claude Code operates in a "blind" mode - writing code without the ability to verify it works in a real browser environment. This is like a developer coding without ever opening their browser.

## Solution Design

### Core Concept
Enable Claude Code to act as a full-stack developer by providing tools to:
1. Open a browser and test features
2. Collect comprehensive error information
3. Correlate browser errors with server logs
4. Iterate on fixes autonomously

### Architecture Overview

```
┌─────────────────────┐
│   Claude Code       │
│                     │
│ 1. Implements       │
│ 2. Tests            │
│ 3. Diagnoses        │
│ 4. Fixes            │
│ 5. Verifies         │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐     ┌─────────────────────┐
│  Browser Testing    │────▶│   Log Aggregator    │
│     Service         │     │                     │
│                     │     │ - Rails logs        │
│ - Capybara          │     │ - Docker logs       │
│ - Error detection   │     │ - Browser console   │
│ - Screenshots       │     │ - Network logs      │
└─────────────────────┘     └─────────────────────┘
```

## Implementation Tasks

### Phase 1: Foundation (Week 1)

#### Task 1.1: Create Browser Testing Service Structure
**Priority**: Critical
**Effort**: 2 hours
**Files**:
- `app/services/browser_testing/base.rb`
- `app/services/browser_testing/configuration.rb`

**Details**:
- Set up service object pattern
- Configure Capybara for Docker environment
- Handle both headless and headful modes
- Ensure Chrome/Chromium is available in container

#### Task 1.2: Basic Test Runner
**Priority**: Critical  
**Effort**: 3 hours
**Files**:
- `app/services/browser_testing/test_runner.rb`
- `lib/tasks/browser_test.rake`

**Details**:
- Create simple page visit functionality
- Capture basic success/failure
- Take screenshots on failure
- Output results in Claude-readable format

#### Task 1.3: Docker Integration
**Priority**: Critical
**Effort**: 2 hours
**Files**:
- Update `Dockerfile`
- Update `docker/entrypoint.sh`

**Details**:
- Add Chrome/Chromium dependencies
- Configure for headless operation
- Ensure proper permissions
- Test in both simple and dual-container modes

### Phase 2: Error Detection (Week 1-2)

#### Task 2.1: Browser Error Collector
**Priority**: High
**Effort**: 4 hours
**Files**:
- `app/services/browser_testing/error_collector.rb`
- `app/services/browser_testing/javascript_error_parser.rb`

**Details**:
- Extract JavaScript console errors
- Capture network errors (404s, 500s)
- Detect Rails error pages
- Parse error stack traces

#### Task 2.2: Log Aggregator
**Priority**: High
**Effort**: 4 hours
**Files**:
- `app/services/browser_testing/log_aggregator.rb`
- `app/services/browser_testing/log_parser.rb`

**Details**:
- Collect Docker logs from all containers
- Parse Rails application logs
- Extract Sidekiq job failures
- Correlate by timestamp and request ID

#### Task 2.3: Error Context Builder
**Priority**: Medium
**Effort**: 3 hours
**Files**:
- `app/services/browser_testing/context_builder.rb`
- `app/services/browser_testing/diagnostic_report.rb`

**Details**:
- Combine browser and server errors
- Add relevant code snippets
- Include suggested fixes
- Format for Claude consumption

### Phase 3: User Journeys (Week 2)

#### Task 3.1: Journey Framework
**Priority**: Medium
**Effort**: 3 hours
**Files**:
- `test/browser/helpers/journey_helper.rb`
- `test/browser/base_journey.rb`

**Details**:
- Create base class for journeys
- Add common assertions
- Handle setup/teardown
- Support data factories

#### Task 3.2: Core User Journeys
**Priority**: Medium
**Effort**: 4 hours
**Files**:
- `test/browser/journeys/user_registration.rb`
- `test/browser/journeys/user_login.rb`
- `test/browser/journeys/create_project.rb`
- `test/browser/journeys/feature_walkthrough.rb`

**Details**:
- Implement happy path for each journey
- Add error condition handling
- Include comprehensive assertions
- Make data-driven and reusable

#### Task 3.3: Journey Runner
**Priority**: Medium
**Effort**: 2 hours
**Files**:
- `app/services/browser_testing/journey_runner.rb`
- Update `lib/tasks/browser_test.rake`

**Details**:
- Execute journeys by name
- Support journey parameters
- Aggregate results
- Generate journey-specific reports

### Phase 4: Self-Healing Loop (Week 2-3)

#### Task 4.1: Error Pattern Matcher
**Priority**: High
**Effort**: 4 hours
**Files**:
- `app/services/browser_testing/error_patterns.rb`
- `app/services/browser_testing/fix_suggester.rb`

**Details**:
- Common Rails error patterns
- JavaScript error patterns
- Missing route detection
- N+1 query detection
- Asset compilation issues

#### Task 4.2: Automated Fix Verification
**Priority**: Medium
**Effort**: 3 hours
**Files**:
- `app/services/browser_testing/fix_verifier.rb`
- `lib/tasks/browser_test.rake` (add verify task)

**Details**:
- Re-run tests after fixes
- Compare error counts
- Detect fix regressions
- Report fix effectiveness

#### Task 4.3: Request Correlation
**Priority**: Low
**Effort**: 3 hours
**Files**:
- `app/middleware/request_id_injector.rb`
- `app/jobs/application_job.rb` (add request_id)
- Update logging configuration

**Details**:
- Add request ID to all logs
- Pass through to background jobs
- Include in browser console
- Enable cross-service tracing

### Phase 5: Claude Integration (Week 3)

#### Task 5.1: Update CLAUDE.md
**Priority**: High
**Effort**: 2 hours
**Files**:
- `CLAUDE.md`
- `docs/workflows/testing-workflow.md`

**Details**:
- Document all new commands
- Add example workflows
- Include troubleshooting guide
- Provide decision tree for test types

#### Task 5.2: Output Formatting
**Priority**: Medium
**Effort**: 2 hours
**Files**:
- `app/services/browser_testing/output_formatter.rb`
- `app/services/browser_testing/claude_formatter.rb`

**Details**:
- Structure output for easy parsing
- Use consistent error format
- Include actionable information
- Add clear success/failure markers

#### Task 5.3: Testing the Tester
**Priority**: Low
**Effort**: 3 hours
**Files**:
- `spec/services/browser_testing/test_runner_spec.rb`
- `spec/services/browser_testing/error_collector_spec.rb`
- `spec/services/browser_testing/log_aggregator_spec.rb`

**Details**:
- Unit tests for services
- Integration tests for rake tasks
- Mock Docker commands
- Verify output formats

## Success Criteria

### Quantitative Metrics
1. **Error Discovery Time**: Reduce from 5-10 minutes to <30 seconds
2. **Fix Iterations**: Reduce from 3-5 cycles to 1-2 cycles
3. **Test Coverage**: Increase from unknown to measurable
4. **Error Context**: Provide 100% of relevant logs

### Qualitative Goals
1. Claude can independently verify feature functionality
2. Error messages provide enough context for fixes
3. Common errors have suggested solutions
4. Testing fits naturally into Claude's workflow

## Technical Considerations

### Performance
- Browser tests are slower than unit tests
- Implement timeouts for hung pages
- Consider parallel test execution
- Cache browser instance between tests

### Docker Constraints
- Chrome requires additional memory
- Headless mode is mandatory in containers
- File permissions for screenshots
- Network isolation between containers

### Error Handling
- Graceful degradation if Chrome unavailable
- Handle container restart scenarios
- Manage test data cleanup
- Deal with flaky network conditions

## Risk Mitigation

### Risks
1. **Complexity Creep**: Solution becomes too complex
   - Mitigation: Start simple, iterate based on usage
   
2. **Performance Impact**: Tests slow down development
   - Mitigation: Optimize critical paths, async where possible
   
3. **False Positives**: Tests fail for unrelated reasons
   - Mitigation: Robust error detection, retry logic
   
4. **Maintenance Burden**: Test code becomes outdated
   - Mitigation: Keep tests simple, document patterns

## Future Enhancements

### Potential Additions
1. Visual regression testing
2. Performance profiling
3. Accessibility checking
4. API endpoint testing
5. WebSocket testing
6. Multi-browser support
7. Test result history
8. Flaky test detection

## Implementation Order

### Recommended Sequence
1. **Week 1**: Foundation + Basic Error Detection
2. **Week 2**: Log Aggregation + Journey Framework  
3. **Week 3**: Self-Healing + Claude Integration

### MVP Definition
The minimum viable product includes:
- Basic browser test runner
- JavaScript error detection
- Docker log collection
- Simple diagnostic reports
- Core user journey tests

## Conclusion

This implementation plan addresses the core problem of Claude Code operating without browser visibility. By providing comprehensive testing and diagnostic tools, we enable Claude to work more autonomously and effectively, reducing the feedback loop from minutes to seconds and eliminating repetitive error-fix cycles.

The phased approach ensures we can deliver value quickly while building toward a comprehensive solution. Starting with basic browser testing and incrementally adding features allows us to validate the approach and adjust based on real usage patterns.