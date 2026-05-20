// esbuild replaces `process.env.NODE_ENV` with a string literal at build
// time (see the `--define` flags in mix.exs `assets.build`/`assets.deploy`
// and the dev watcher in config/dev.exs). This ambient declaration just
// gives editors/TypeScript the type — `process` itself never reaches the
// bundle.
declare const process: {
  env: { NODE_ENV?: 'development' | 'production' };
};
