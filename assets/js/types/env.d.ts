// esbuild replaces `process.env.NODE_ENV` with a string literal at build
// time (see the `--define` flags in mix.exs `assets.build`/`assets.deploy`
// and the dev watcher in config/dev.exs). This ambient declaration just
// gives editors/TypeScript the type — `process` itself never reaches the
// bundle.
declare const process: {
  env: {
    NODE_ENV?: 'development' | 'production';
    // Read only by ssr.tsx, which runs in a real Node worker (spawned by
    // the BEAM) and inherits these from the deploy environment. They never
    // reach the browser bundle.
    SENTRY_DSN_SSR?: string;
    SENTRY_DSN_FRONTEND?: string;
    SENTRY_RELEASE?: string;
    // Render sets this (the commit SHA) at runtime; used as the release
    // when SENTRY_RELEASE is unset.
    RENDER_GIT_COMMIT?: string;
    // Deploy tier (staging/qa/production); the Sentry environment.
    DEPLOY_ENV?: string;
  };
};
