// Wrapper Type
class Optional<T> {
  private value: T | null;

  constructor(value: T | null) {
    this.value = value;
  }

  // Wrap Function
  public static of<T>(value: T): Optional<T> {
    return new Optional(value);
  }

  public static empty<T>(): Optional<T> {
    return new Optional<T>(null);
  }

  public map<U>(fn: (value: T) => U): Optional<U> {
    return this.value === null ? Optional.empty<U>() : Optional.of(fn(this.value));
  }

  public flatMap<U>(fn: (value: T) => Optional<U>): Optional<U> {
    return this.value === null ? Optional.empty<U>() : fn(this.value);
  }

  public isPresent(): boolean {
    return this.value !== null;
  }

  public get(): T {
    if (this.value === null) {
      throw new Error('Value is null');
    }

    return this.value;
  }
}
