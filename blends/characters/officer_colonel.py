"""Second Army officer: a stockier, older Colonel (variation of officer.py).
Run:  blender -b -P blends/characters/officer_colonel.py
Silver eagle rank, gray hair + mustache, brown skin, 'pinks' trousers, braided cap visor.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import officer  # noqa: E402

COLONEL = dict(officer.MAJOR, name="officer_colonel", skin="skin_brown", skin_shade="skin_brown_shade",
               hair="hair_gray", trousers="army_pinks", rank="eagle", bulk=1.07, mustache=True, braid=True)

if __name__ == "__main__":
    officer.build(COLONEL)
