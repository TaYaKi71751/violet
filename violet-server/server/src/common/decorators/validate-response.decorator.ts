import { validateSync, validateOrReject } from 'class-validator';
import { plainToInstance, ClassConstructor } from 'class-transformer';
import { InternalServerErrorException } from '@nestjs/common';

type AnyFn<A extends any[] = any[], R = any> = (...args: A) => R;

export function ValidateResponse<T>(dtoClass: ClassConstructor<T>) {
    return function <
        A extends any[],
        R
    >(
        _target: any,
        _propertyKey: string,
        descriptor: TypedPropertyDescriptor<AnyFn<A, R>>
    ) {
        const original = descriptor.value!;
        descriptor.value = function (...args: A): R {
            const out = original.apply(this, args) as R;

            const runValidate = (value: any) => {
                // DTO 인스턴스로 변환
                const instance = plainToInstance(dtoClass, value);

                // 값이 배열이면 각 요소 검증
                const doSync = (v: any) => {
                    if (Array.isArray(v)) {
                        const errs = v.flatMap(item => validateSync(item));
                        if (errs.length) throw new InternalServerErrorException('Fail to validate response');
                    } else {
                        const errs = validateSync(v);
                        if (errs.length) throw new InternalServerErrorException('Fail to validate response');
                    }
                    return value; // 항상 원본 값을 그대로 반환
                };

                return doSync(instance);
            };

            // 비동기 반환(Promise)이면 then에서 검증
            if (out && typeof (out as any).then === 'function') {
                return (out as any).then((val: any) => {
                    const instance = plainToInstance(dtoClass, val);
                    // 비동기 커스텀 validator를 쓰는 경우를 대비해 async 검증 사용
                    return Promise.resolve(
                        Array.isArray(instance)
                            ? Promise.all(instance.map(i => validateOrReject(i)))
                            : validateOrReject(instance as any)
                    ).then(() => val);
                }) as any as R;
            }

            // 동기 반환이면 동기 검증으로 타입 유지
            return runValidate(out) as any as R;
        };
        return descriptor;
    };
}
