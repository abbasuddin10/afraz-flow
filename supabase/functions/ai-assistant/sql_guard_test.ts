import {
  assertThrows,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { assertSafeSql, utcOffsetLabel } from "./sql_guard.ts";

const TENANT = "0b9f3b52-4a5e-4f3c-9d21-7b8a6c5d4e3f";
const OTHER_TENANT = "11111111-2222-3333-4444-555555555555";

const VALID_SQL =
  `select p.name, p.stock_qty from public.products p ` +
  `where p.tenant_id = '${TENANT}' and p.is_active = true`;

Deno.test("accepts a tenant-scoped read-only SELECT", () => {
  assertEquals(assertSafeSql(VALID_SQL, TENANT), VALID_SQL);
});

Deno.test("accepts WITH queries and strips a trailing semicolon", () => {
  const sql =
    `with low as (select * from products where tenant_id = '${TENANT}' ` +
    `and stock_qty <= low_stock_threshold) ` +
    `select name, stock_qty from low;`;
  const parsed = assertSafeSql(sql, TENANT);
  assertEquals(parsed.endsWith(";"), false);
  assertStringIncludes(parsed, "with low as");
});

Deno.test("accepts role as a column name", () => {
  const sql =
    `select role, user_id from tenant_members where tenant_id = '${TENANT}'`;
  assertEquals(assertSafeSql(sql, TENANT), sql);
});

Deno.test("rejects write and DDL statements", () => {
  const attacks = [
    `delete from products where tenant_id = '${TENANT}'`,
    `update products set stock_qty = 0 where tenant_id = '${TENANT}'`,
    `insert into products (tenant_id) values ('${TENANT}')`,
    `with gone as (delete from products where tenant_id = '${TENANT}' returning *) select * from gone`,
    `drop table products`,
    `alter table products add column x int`,
    `select * from products where tenant_id = '${TENANT}' for update`,
    `select public.checkout_sale('${TENANT}'::uuid)`,
    `select pg_sleep(10)`,
    `select set_config('statement_timeout', '0', false)`,
  ];

  for (const sql of attacks) {
    assertThrows(() => assertSafeSql(sql, TENANT), Error);
  }
});

Deno.test("rejects multiple statements and comments", () => {
  assertThrows(
    () =>
      assertSafeSql(
        `select 1 from products where tenant_id = '${TENANT}'; delete from products`,
        TENANT,
      ),
    Error,
  );
  assertThrows(
    () =>
      assertSafeSql(
        `select * from products -- comment\nwhere tenant_id = '${TENANT}'`,
        TENANT,
      ),
    Error,
  );
  assertThrows(
    () =>
      assertSafeSql(
        `select /* hide */ * from products where tenant_id = '${TENANT}'`,
        TENANT,
      ),
    Error,
  );
});

Deno.test("rejects protected schemas and functions", () => {
  assertThrows(
    () => assertSafeSql(`select * from auth.users`, TENANT),
    Error,
  );
  assertThrows(
    () =>
      assertSafeSql(
        `select * from storage.objects where owner_id = '${TENANT}'`,
        TENANT,
      ),
    Error,
  );
  assertThrows(
    () =>
      assertSafeSql(
        `select * from information_schema.tables where table_schema = '${TENANT}'`,
        TENANT,
      ),
    Error,
  );
});

Deno.test("requires an explicit tenant equality filter", () => {
  assertThrows(
    () => assertSafeSql(`select * from products`, TENANT),
    Error,
  );
  assertThrows(
    () =>
      assertSafeSql(
        `select * from products where name = '${TENANT}'`,
        TENANT,
      ),
    Error,
  );
  assertThrows(
    () =>
      assertSafeSql(
        `select * from products where tenant_id = '${OTHER_TENANT}'`,
        TENANT,
      ),
    Error,
  );
});

Deno.test("formats UTC offsets for SQL date conversion", () => {
  assertEquals(utcOffsetLabel(360), "+06:00");
  assertEquals(utcOffsetLabel(330), "+05:30");
  assertEquals(utcOffsetLabel(-300), "-05:00");
  assertEquals(utcOffsetLabel(0), "+00:00");
  assertEquals(utcOffsetLabel(null), "+00:00");
});
