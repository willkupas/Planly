/**
 * Relógio injetável (jobs agendados e testes). Em produção `systemClock`; nos testes
 * `fixedClock(ms)` permite simular dias passando sem esperar.
 */
export interface Clock {
  nowMs(): number;
}

export const systemClock: Clock = { nowMs: () => Date.now() };

/** Relógio controlável: `set`/`advance` mudam a hora corrente. */
export function fixedClock(startMs: number): Clock & { set(ms: number): void; advance(ms: number): void } {
  let t = startMs;
  return {
    nowMs: () => t,
    set: (ms: number) => {
      t = ms;
    },
    advance: (ms: number) => {
      t += ms;
    },
  };
}
