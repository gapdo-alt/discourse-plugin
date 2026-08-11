import { helper } from "@ember/component/helper";
import { htmlSafe } from "@ember/template";

export function formatEmployeeIdHtml([id]) {
  const s = String(id ?? "")
    .replace(/\D/g, "")
    .padStart(8, "0");
  if (s.length !== 8) {
    return id;
  }
  const html = `<span class="snowball-id-part">${s.slice(0, 2)}</span><span class="snowball-id-part">${s.slice(2, 5)}</span><span class="snowball-id-part">${s.slice(5, 8)}</span>`;
  return htmlSafe(html);
}

export default helper(formatEmployeeIdHtml);
