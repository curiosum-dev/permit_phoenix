# Pull Request

## Description

<!-- Provide a clear and concise description of what this PR does -->

## Type of Change

<!-- Mark the relevant option with an "x" -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring
- [ ] Test improvements
- [ ] CI/CD improvements

## Related Issues

<!-- Link any related issues -->
Fixes #<!-- issue number -->
Closes #<!-- issue number -->
Related to #<!-- issue number -->

## Changes Made

<!-- List the main changes made in this PR -->

-
-
-

## Testing

<!-- Describe the tests you ran to verify your changes -->

### Test Environment
- [ ] Elixir version: <!-- e.g., 1.17.0 -->
- [ ] OTP version: <!-- e.g., 27 -->
- [ ] Phoenix version: <!-- e.g., 1.7.0 -->
- [ ] LiveView version: <!-- e.g., 0.20.0 -->
- [ ] Database (if applicable): <!-- e.g., PostgreSQL 14 -->

### Test Cases
- [ ] All existing tests pass
- [ ] New tests added for new functionality at appropriate levels
- [ ] Manual testing performed
- [ ] Controller integration tests (if applicable)
- [ ] LiveView integration tests (if applicable)
- [ ] Router integration tests (if applicable)

### Test Commands Run
```bash
# List the commands you ran to test
mix test
MIX_ENV=test mix credo
MIX_ENV=test mix dialyzer
```

## Documentation

- [ ] Updated README.md (if applicable)
- [ ] Updated documentation comments (with examples for new features)
- [ ] Updated CHANGELOG.md (if applicable)
- [ ] Updated controller/LiveView usage examples (if applicable)

## Code Quality

- [ ] Code follows the existing style conventions
- [ ] Self-review of the code has been performed
- [ ] Code has been commented, particularly in hard-to-understand areas
- [ ] No new linting warnings introduced
- [ ] No new Dialyzer warnings introduced
- [ ] Follows Phoenix and LiveView conventions

## Phoenix/LiveView Specific

- [ ] Controller changes properly handle conn state
- [ ] LiveView changes properly handle socket state
- [ ] Router integration works correctly
- [ ] Error handling follows Phoenix patterns
- [ ] Authorization flows work as expected

## Backward Compatibility

- [ ] This change is backward compatible
- [ ] This change includes breaking changes (please describe below)
- [ ] Migration guide provided for breaking changes

### Breaking Changes
<!-- If there are breaking changes, describe them here -->

## Performance Impact

- [ ] No performance impact
- [ ] Performance improvement
- [ ] Potential performance regression (please describe)

### Performance Notes
<!-- Describe any performance considerations -->

## Security Considerations

- [ ] No security impact
- [ ] Security improvement
- [ ] Potential security impact (please describe)

## Additional Notes

<!-- Any additional information that reviewers should know -->

## Screenshots/Examples

<!-- If applicable, add screenshots or code examples -->

```elixir
# Example usage of new feature
defmodule MyAppWeb.ArticleController do
  use Permit.Phoenix.Controller,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article

  # New functionality here
end
```

## Checklist

- [ ] I have read the [Contributing Guidelines](CONTRIBUTING.md)
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

## Reviewer Notes

<!-- Any specific areas you'd like reviewers to focus on -->

---

<!-- Thank you for contributing to Permit.Phoenix! -->
