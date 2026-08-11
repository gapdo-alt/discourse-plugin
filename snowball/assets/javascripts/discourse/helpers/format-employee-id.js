import { helper } from "@ember/component/helper";

export function formatEmployeeId([id]) {
  const s = String(id ?? "")
    .replace(/\D/g, "")
    .padStart(8, "0");
  if (s.length !== 8) {
    return id;
  }
  return `${s.slice(0, 2)} ${s.slice(2, 5)} ${s.slice(5, 8)}`;
}

export default helper(formatEmployeeId);
