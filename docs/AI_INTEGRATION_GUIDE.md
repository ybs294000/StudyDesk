# AI Integration Guide

This document describes the intended integration posture for optional AI-assisted features in StudyDesk.

## Core Position

AI is treated as an optional enhancement, not a dependency for the core product.

StudyDesk should remain useful without:

- provider accounts
- network connectivity
- cloud-hosted inference

## Current Repository Status

The current StudyDesk repository does not ship an end-user AI feature set as part of the implemented core workflow.

What exists today:

- keyword-graded Q&A questions
- structured model answers
- deterministic local quiz grading logic

What this document describes:

- future-facing AI integration principles
- expected storage and provider boundaries
- implementation constraints for any future AI-assisted grading or explanation flow

## Integration Principles

### Optional by design

Core study actions must remain available when AI is disabled, unavailable, or not configured.

### User-controlled credentials

If provider access is added later, credentials should be user-supplied and stored locally on the device using platform-appropriate secure storage.

### No hidden dependency

StudyDesk should not silently convert local study actions into remote-provider calls.

### Clear fallback behavior

If an AI-assisted flow is unavailable, the app should fall back to deterministic local behavior rather than failing the surrounding study workflow.

## Candidate Future Uses

Potential future integrations include:

- AI-assisted short-answer grading as an optional layer above local keyword grading
- concise explanation generation for incorrect answers
- export-oriented study summaries for external analysis

These uses should remain secondary to the local-first baseline already present in the repository.

## Storage and Security Expectations

If AI provider support is added in the future, the implementation should follow these rules:

- credentials stored only in secure local storage
- HTTPS-only provider communication
- explicit provider selection by the user
- no hardcoded secrets in the client
- no silent background submission of study content

## UX Expectations

Any future AI-supported screen should make these things obvious:

- whether AI is currently configured
- which provider is selected
- what content is being sent off-device
- what local fallback behavior applies if the AI path is unavailable

## Compatibility with Current Grading

StudyDesk already contains a real local grading system for Q&A-style short answers.

If AI-assisted grading is added later, it should complement rather than replace the current deterministic baseline:

- local keyword grading remains available
- AI grading should be opt-in
- review screens should still remain intelligible without provider output
