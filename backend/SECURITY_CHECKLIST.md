# Backend secrets checklist

Review before any commit that touches `backend/`, and again before System Preview / final submission.

- [ ] `backend/config.php` stays out of git — check `git status` shows it ignored, not untracked, before every commit
- [ ] `backend/config.example.php` stays in sync with whatever keys `config.php` actually uses (update both together)
- [ ] `jwt_secret` in `config.php` is a real random value before Phase 3 auth is wired up — the placeholder here is not secure
- [ ] MySQL root has an empty password by default in local XAMPP — fine for solo local dev, but if this ever moves to a shared/networked machine (e.g. demoing on a lab PC), set a real MySQL password and update `config.php` to match
- [ ] Before recording a demo video or pushing anything public: double check no terminal output, screenshot, or committed file shows `config.php`'s contents
