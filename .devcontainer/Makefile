# Devcontainer Testing Makefile
# For chipflow-template developers to test the devcontainer builds

.PHONY: help test clean

help:
	@echo "Devcontainer Testing - Available targets:"
	@echo "  test   - Build the devcontainer Docker image to verify it works"
	@echo "  clean  - Remove test Docker image and build cache"
	@echo "  help   - Show this help message"

test:
	@echo "Building devcontainer Docker image..."
	@docker build \
		--build-context src=.. \
		-f Dockerfile \
		-t chipflow-template-devcontainer-test \
		.
	@echo "✅ Devcontainer build successful!"
	@echo ""
	@echo "To test interactively:"
	@echo "  docker run -it chipflow-template-devcontainer-test /bin/bash"

clean:
	@echo "Cleaning Docker build cache..."
	@docker builder prune -f
	@docker image rm chipflow-template-devcontainer-test 2>/dev/null || true
	@echo "✅ Clean complete"
