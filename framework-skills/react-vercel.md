# Vercel React Best Practices
# Source: skills.sh/vercel-labs/agent-skills/vercel-react-best-practices
# Auto-fetched and committed to bug-hunter-d33

## Overview
Comprehensive performance optimization guide for React and Next.js applications, maintained by Vercel. Contains 58 rules across 8 categories, prioritized by impact.

## Priority 1: Eliminating Waterfalls (CRITICAL)

- **async-defer-await** - Move await into branches where actually used
- **async-parallel** - Use Promise.all() for independent operations  
- **async-dependencies** - Use better-all for partial dependencies
- **async-api-routes** - Start promises early, await late in API routes
- **async-suspense-boundaries** - Use Suspense to stream content

## Priority 2: Bundle Size Optimization (CRITICAL)

- **bundle-barrel-imports** - Import directly, avoid barrel files
- **bundle-dynamic-imports** - Use next/dynamic for heavy components
- **bundle-defer-third-party** - Load analytics/logging after hydration
- **bundle-conditional** - Load modules only when feature is activated
- **bundle-preload** - Preload on hover/focus for perceived speed

## Priority 3: Server-Side Performance (HIGH)

- **server-auth-actions** - Authenticate server actions like API routes
- **server-cache-react** - Use React.cache() for per-request deduplication
- **server-cache-lru** - Use LRU cache for cross-request caching
- **server-dedup-props** - Avoid duplicate serialization in RSC props
- **server-hoist-static-io** - Hoist static I/O (fonts, logos) to module level
- **server-serialization** - Minimize data passed to client components
- **server-parallel-fetching** - Restructure components to parallelize fetches
- **server-after-nonblocking** - Use after() for non-blocking operations

## Priority 4: Client-Side Data Fetching (MEDIUM-HIGH)

- **client-swr-dedup** - Use SWR for automatic request deduplication
- **client-event-listeners** - Deduplicate global event listeners
- **client-passive-event-listeners** - Use passive listeners for scroll
- **client-localstorage-schema** - Version and minimize localStorage data

## Priority 5: Re-render Optimization (MEDIUM)

- **rerender-memo** - Extract expensive work into memoized components
- **rerender-memo-with-default-value** - Hoist default non-primitive props
- **rerender-dependencies** - Use primitive dependencies in effects
- **rerender-derived-state** - Subscribe to derived booleans, not raw values
- **rerender-functional-setstate** - Use functional setState for stable callbacks
- **rerender-lazy-state-init** - Pass function to useState for expensive values
- **rerender-transitions** - Use startTransition for non-urgent updates

## Priority 6: Rendering Performance (MEDIUM)

- **rendering-animate-svg-wrapper** - Animate div wrapper, not SVG element
- **rendering-content-visibility** - Use content-visibility for long lists
- **rendering-hoist-jsx** - Extract static JSX outside components
- **rendering-hydration-no-flicker** - Use inline script for client-only data
- **rendering-conditional-render** - Use ternary, not && for conditionals

## Priority 7-8: JavaScript & Advanced Patterns

See full rules for: batching DOM changes, caching lookups, early exits, event handler refs.

## Bug Hunter Focus Areas

When reviewing React/Next.js code, prioritize:
1. Waterfall data fetching patterns
2. Missing useMemo/useCallback for expensive computations
3. Improper effect dependencies
4. Barrel file imports in hot paths
5. Missing Suspense boundaries for async content
