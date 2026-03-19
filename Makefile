check: check-rust check-frontend

check-rust:
	cargo fmt --all -- --check
	cargo clippy --workspace --all-targets --all-features -- -D warnings
	cargo test --workspace

check-frontend:
	pnpm --filter frontend run lint
	pnpm --filter frontend run build

check-security:
	cargo audit

ci: check check-security