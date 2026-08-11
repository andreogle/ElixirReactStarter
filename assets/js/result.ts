/** A successful tuple with no error and a value. */
export type Success<T> = readonly [error: undefined, value: T];

/** A failed tuple with an error and no value. */
export type Failure<E extends Error = Error> = readonly [error: E, value: undefined];

/** A discriminated error-first tuple result. */
export type Result<T, E extends Error = Error> = Success<T> | Failure<E>;

/** Context supplied to each execution attempt. Attempts are one-based. */
export type AttemptContext = Readonly<{
  attempt: number;
  signal: AbortSignal;
}>;

/** Context supplied when deciding whether and when to retry. */
export type RetryContext = Readonly<{
  attempt: number;
  attempts: number;
  error: Error;
}>;

/** Optional execution policy for {@link go}. */
export type GoOptions = Readonly<{
  /** Total safe-integer executions, including the first. Defaults to one. */
  attempts?: number;
  /** Fixed or computed delay from 0 to 2,147,483,647ms. Defaults to zero. */
  delayMs?: number | ((context: RetryContext) => number);
  /** Explicitly approves another attempt. Failures are not retried by default. */
  shouldRetry?: (context: RetryContext) => boolean | PromiseLike<boolean>;
  /** Caller-controlled cancellation signal. */
  signal?: AbortSignal;
  /** Per-attempt timeout from 1 to 2,147,483,647ms. No timeout by default. */
  timeoutMs?: number;
}>;

/** Creates a successful result. */
export const ok = <T>(value: T): Success<T> => [undefined, value];

/** Creates a failed result. */
export const err = <E extends Error>(error: E): Failure<E> => [error, undefined];

/** Narrows a result to its success branch, for expression positions such as {@link Array.filter}. */
export const isOk = <T, E extends Error>(result: Result<T, E>): result is Success<T> => result[0] === undefined;

/** Narrows a result to its failure branch, for expression positions such as {@link Array.filter}. */
export const isErr = <T, E extends Error>(result: Result<T, E>): result is Failure<E> => result[0] !== undefined;

/** Error returned when an individual execution attempt exceeds its timeout. */
export class TimeoutError extends Error {
  override readonly name = 'TimeoutError';
  readonly attempt: number;
  readonly timeoutMs: number;

  constructor(timeoutMs: number, attempt: number) {
    super(`Attempt ${attempt} timed out after ${timeoutMs}ms`);
    this.attempt = attempt;
    this.timeoutMs = timeoutMs;
  }
}

const normalizeError = (cause: unknown): Error => {
  if (cause instanceof Error) {
    return cause;
  }

  let message = 'Non-Error value thrown';

  try {
    message = String(cause);
  } catch {
    // Keep the stable fallback while preserving the original value as the cause.
  }

  return new Error(message, { cause });
};

/** Converts a synchronous throw into a tuple result. */
export const goSync = <T>(operation: () => T): Result<T> => {
  try {
    return ok(operation());
  } catch (cause) {
    return err(normalizeError(cause));
  }
};

/** Converts synchronous throws and Promise rejections into a tuple result. */
const capture = async <T>(operation: () => T | PromiseLike<T>): Promise<Result<Awaited<T>>> => {
  try {
    return ok(await operation());
  } catch (cause) {
    return err(normalizeError(cause));
  }
};

const MAX_TIMER_MS = 2_147_483_647;

const validateTimerMs = (name: string, value: number, minimum: number): void => {
  if (!Number.isFinite(value) || value < minimum || value > MAX_TIMER_MS) {
    throw new RangeError(`${name} must be a finite number between ${minimum} and ${MAX_TIMER_MS}`);
  }
};

const isAbortSignal = (value: unknown): value is AbortSignal => {
  const candidate = value as AbortSignal | null;

  return (
    typeof candidate === 'object' &&
    candidate !== null &&
    typeof candidate.aborted === 'boolean' &&
    typeof candidate.addEventListener === 'function' &&
    typeof candidate.removeEventListener === 'function'
  );
};

/** Validates fixed options before any work starts and returns the attempt count. */
const validateOptions = (options: GoOptions): number => {
  if (typeof options !== 'object' || options === null || Array.isArray(options)) {
    throw new TypeError('options must be an object');
  }

  const { attempts = 1, delayMs, shouldRetry, signal, timeoutMs } = options;

  if (!Number.isSafeInteger(attempts) || attempts < 1) {
    throw new RangeError('attempts must be a positive safe integer');
  }
  if (timeoutMs !== undefined) {
    validateTimerMs('timeoutMs', timeoutMs, 1);
  }
  if (typeof delayMs === 'number') {
    validateTimerMs('delayMs', delayMs, 0);
  } else if (delayMs !== undefined && typeof delayMs !== 'function') {
    throw new TypeError('delayMs must be a number or function');
  }
  if (shouldRetry !== undefined && typeof shouldRetry !== 'function') {
    throw new TypeError('shouldRetry must be a function');
  }
  if (signal !== undefined && !isAbortSignal(signal)) {
    throw new TypeError('signal must be an AbortSignal');
  }

  return attempts;
};

const abortReason = (signal: AbortSignal): Error => normalizeError(signal.reason);

/**
 * Invokes `listener` at most once when the signal aborts, including when it is
 * already aborted or aborts while the listener is being registered. Returns a
 * best-effort unsubscribe; a signal that rejects registration rethrows.
 */
const onAbort = (signal: AbortSignal, listener: () => void): (() => void) => {
  let notified = false;
  const fire = (): void => {
    if (notified) {
      return;
    }
    notified = true;
    listener();
  };
  const detach = (): void => {
    try {
      signal.removeEventListener('abort', fire);
    } catch {
      // Cleanup is best-effort and must not replace the original result.
    }
  };

  if (signal.aborted) {
    fire();
    return detach;
  }

  try {
    signal.addEventListener('abort', fire, { once: true });
  } catch (cause) {
    detach();
    throw cause;
  }

  if (signal.aborted) {
    fire();
  }

  return detach;
};

/** Settles with `value`, or rejects with the abort reason if the signal wins. */
const abortable = async <T>(value: T | PromiseLike<T>, signal: AbortSignal | undefined): Promise<T> => {
  const settled = Promise.resolve(value);
  void settled.catch(() => undefined);

  if (signal === undefined) {
    return await settled;
  }
  if (signal.aborted) {
    throw abortReason(signal);
  }

  let detach: (() => void) | undefined;

  try {
    return await new Promise<T>((resolve, reject) => {
      detach = onAbort(signal, () => reject(abortReason(signal)));
      settled.then(resolve, reject);
    });
  } finally {
    detach?.();
  }
};

/** Waits for the delay, rejecting early with the abort reason if the signal wins. */
const wait = async (delayMs: number, signal: AbortSignal | undefined): Promise<void> => {
  if (signal?.aborted) {
    throw abortReason(signal);
  }
  if (delayMs === 0) {
    return;
  }

  let timeout: ReturnType<typeof setTimeout> | undefined;

  try {
    await abortable<void>(
      new Promise<void>((resolve) => {
        timeout = setTimeout(resolve, delayMs);
      }),
      signal
    );
  } finally {
    clearTimeout(timeout);
  }
};

/** Runs one attempt against a signal that this package aborts on timeout or cancellation. */
const executeAttempt = async <T>(
  operation: (context: AttemptContext) => T | PromiseLike<T>,
  attempt: number,
  timeoutMs: number | undefined,
  externalSignal: AbortSignal | undefined
): Promise<Awaited<T>> => {
  const controller = new AbortController();
  let detach: (() => void) | undefined;
  let timeout: ReturnType<typeof setTimeout> | undefined;

  try {
    if (externalSignal !== undefined) {
      detach = onAbort(externalSignal, () => controller.abort(abortReason(externalSignal)));
    }
    if (timeoutMs !== undefined) {
      timeout = setTimeout(() => controller.abort(new TimeoutError(timeoutMs, attempt)), timeoutMs);
    }

    return await abortable(
      Promise.resolve().then(() => {
        if (controller.signal.aborted) {
          throw abortReason(controller.signal);
        }
        return operation({ attempt, signal: controller.signal });
      }),
      controller.signal
    );
  } finally {
    clearTimeout(timeout);
    detach?.();
  }
};

/**
 * Converts synchronous throws and Promise rejections into a tuple result.
 *
 * Options add a per-attempt timeout, caller cancellation, and explicitly
 * approved sequential retries.
 */
export const go = async <T>(
  operation: (context: AttemptContext) => T | PromiseLike<T>,
  options: GoOptions = {}
): Promise<Result<Awaited<T>>> => {
  let attempts: number;

  try {
    attempts = validateOptions(options);
  } catch (cause) {
    return err(normalizeError(cause));
  }

  const { delayMs, shouldRetry, signal, timeoutMs } = options;

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    if (signal?.aborted) {
      return err(abortReason(signal));
    }

    const [error, value] = await capture(() => executeAttempt(operation, attempt, timeoutMs, signal));

    if (error === undefined) {
      return ok(value);
    }
    if (signal?.aborted) {
      return err(abortReason(signal));
    }
    if (attempt === attempts || shouldRetry === undefined) {
      return err(error);
    }

    const context: RetryContext = { attempt, attempts, error };
    const [policyError, approved] = await capture(async () => {
      if (!(await abortable(shouldRetry(context), signal))) {
        return false;
      }

      const delay = typeof delayMs === 'function' ? delayMs(context) : (delayMs ?? 0);

      validateTimerMs('delayMs', delay, 0);
      await wait(delay, signal);
      return true;
    });

    // Caller cancellation is terminal, so it outranks any policy failure.
    if (policyError !== undefined) {
      return err(signal?.aborted ? abortReason(signal) : policyError);
    }
    if (!approved) {
      return err(error);
    }
  }

  throw new Error('Unreachable retry state');
};
