# A Dutch Wadden Sea Ecosystem Digital Twin
This repository contains the model setup for developing a **3D ecosystem Digital Twin of the Dutch Wadden Sea** based on the coupled **GETM-ERSEM–BFM** hydrodynamic–biogeochemical modelling framework.

---
A **Digital Twin** is defined as:

> *"A digital twin is a computational model of an intended or actual real-world physical product, system, or process (a physical twin) that serves as a digital counterpart of it for purposes such as simulation, integration, testing, monitoring, and maintenance."*
> *(Source: https://en.wikipedia.org/wiki/Digital_twin)*

An **ecosystem Digital Twin** extends this concept by integrating process-based models, observations, and data-driven approaches to represent ecosystem states and dynamics. The key characteristics and requirements of ecosystem Digital Twins are discussed in our recent publication:

🔗*Visser et al. (2026)*: https://www.sciencedirect.com/science/article/pii/S0169534726001035

---

## Physical Twin of the Wadden Sea Ecosystem

The Wadden Sea is the world's largest continuous intertidal ecosystems and a UNESCO World Heritage Site. The Wadden Sea ecosystem in the real-world:

<img width="2434" height="1728" alt="DWS-Image-enhanced" src="https://github.com/user-attachments/assets/7bcfbbb9-91f2-4abf-b726-f985f18c316d" />

© 2026, *Tjitske Kooistra*

## Digital Twin of the Wadden Sea Ecosystem:
The Digital Twin represents the coupled physical and ecological processes of the Wadden Sea through high-resolution numerical modelling and interactive data exploration.

https://github.com/user-attachments/assets/ab2ff978-1a69-49f5-863b-5069ba22b703

Note that the vertical exaggeration 100x. 
The app is under development. © 2026, *Petros Giannopoulos (https://github.com/PetrosGiannopoulos)*

---
## Model Architecture
The current implementation combines:
- **Hydrodynamics**: water circulation, tides, and transport processes
- **Biogeochemistry**: nutrient cycling, pelagic and benthic organisms
- **Model-based simulations**: four-dimensional (3D + time) representation of ecosystem states

<img src="./Graphs/schema_DWS.png" alt="Model schema" width="700">

- Meta data for biogeochemical variables can be found in: ./Container_dependency/GlobalDefsBFM.model.orig
---

## Model 3d example outputs
### Top view:
<a href="./Graphs/transect_temp_surface_domain.gif">
  <img src="./Graphs/pelagic_diatom_top.gif" alt="Top view pelagic diatom" width="700">
</a>

### Transect view:
<a href="./Graphs/transect_elevation_PO4.gif">
  <img src="./Graphs/pelagic_diatom_transect.gif" alt="Transect pelagic diatom" width="700">
</a>
---

## Wadden Sea Ecosystem Model Output as a Service (Wad_EMOaaS):
**Wad_EMOaaS** is an interactive virtual laboratory developed within the **LTER-LIFE** project for exploring four-dimensional (3D + time) hydro-biogeochemical model outputs of the Dutch Wadden Sea.

🔗 **Wad_EMOaaS Virtual Lab:** https://beta.naavre.net/vreapp/vl/wad-emoaas

<img width="1900" height="942" alt="DWS_N1p_2" src="https://github.com/user-attachments/assets/2165dd0a-416f-487b-9777-ab38a9cd0545" />

---

## Computational Requirements
Approximate computational resources for running the model:

| Resource | Requirement |
|----------|-------------|
| GPU | Not required |
| CPU | ~240 cores (tested); scalability to 1000–2000 cores to be evaluated |
| Memory | Depends on domain size; no memory bottlenecks observed in current configuration |
| Storage | 1–5 TB for exploratory simulations; 5–10 TB for production-scale simulations |


---

## Contact

The ecosystem Digital Twin and **Wad_EMOaaS** are under active development.

Questions, suggestions, and collaborations are welcome. Please open an issue in this repository or contact the developers:
Qing Zhan (qing.zhan@nioz.nl); Christos Giannopoulos (christos.giannopoulos@nioz.nl) 

---

## License

The contents of this repository are currently under preparation for publication. Therefore, the model assets, data, and associated resources should not be reused, redistributed, or modified without prior consultation with the developers.

For citation information and guidelines, please refer to:

`CITATION.cff`




