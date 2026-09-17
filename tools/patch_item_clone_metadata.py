from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "src" / "item_factory.gd"

old = '''\tnew_item.stim_turns = item.stim_turns\n\tnew_item._mass = item._mass\n\treturn new_item\n'''
new = '''\tnew_item.stim_turns = item.stim_turns\n\tnew_item._mass = item._mass\n\t# Runtime systems attach identity/progression data as metadata (for example\n\t# Nightreign weapon archetype and affinity). A clone must keep that identity.\n\tfor meta_name: StringName in item.get_meta_list():\n\t\tnew_item.set_meta(meta_name, item.get_meta(meta_name))\n\treturn new_item\n'''

text = PATH.read_text(encoding="utf-8")
if new in text:
    print("item clone metadata patch already present")
elif text.count(old) == 1:
    PATH.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("patched ItemFactory.clone metadata preservation")
else:
    raise RuntimeError(f"expected exactly one ItemFactory.clone tail, found {text.count(old)}")
