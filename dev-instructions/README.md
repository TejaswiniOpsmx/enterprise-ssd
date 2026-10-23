
Instructions updating the try-ssd.yaml
- clone this repo to local
- update rcimages-values.yaml, we should not need to change values.yaml OR the minimal*yaml.
- cd charts/ssd
- ```helm template ssd . -n try-ssd  -f rcimages-values.yaml -f minimal-local-values.yaml > ../..try-ssd.yaml```
- push to the repo
- Test it once EXACTLY following the instructions in the README

  **DO NOT change anything as Srini is working on it. If there are any config changes, please let Srini known.**
