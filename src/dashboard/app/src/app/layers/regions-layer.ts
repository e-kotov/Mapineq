import L from "leaflet";
import {BaseLayer} from "./base-layer";
import config from '../../assets/config.json';

export class RegionsLayer extends BaseLayer  {


  constructor() {
    super();

  }


  public static getLayer(nutslevel: string, year: string): any {



    //let nutsid = 3;
    let nutsUrl = config.tileServer + "areas.get_nuts_areas_tiles" + "/{z}/{x}/{y}.pbf" + "?year=" + year + "&intlevel=" + nutslevel;

    let options = {
      // @ts-ignore
      rendererFactory: L.canvas.tile,
      interactive: true,
      vectorTileLayerStyles: {
        default: {
          weight: 1,
          color: '#da0a0a',
          /*
          color: 'rgba(185,178,178,0.8)',
          */
          fill: true,
          fillColor: '#DA0A0A',
          /*
          fillColor: '#ffffff',
          */
          fillOpacity: 1,
        }
      },
      getFeatureId: function(f) {
        return f.properties["nuts_id"];
      }
    }

    /* /
    //From https://gis.stackexchange.com/questions/474627/get-events-fired-for-all-objects-in-a-protobuf-layer-when-clicked-on-in-leaflet
    //@ts-ignore
    L.Canvas.Tile.include({
      _onClick: function (e:any) {
        let point = this._map.mouseEventToLayerPoint(e).subtract(this.getOffset()), layer, clickedLayer;
        const layers = [];

        for (const id in this._layers) {
          layer = this._layers[id];
          if (layer.options.interactive && layer._containsPoint(point) && !this._map._draggableMoved(layer)) {
            clickedLayer = layer;
            layers.push(layer);
          }
        }
        if (clickedLayer)  {
          e._layers = layers;
          // @ts-ignore
          //L.DomEvent.fakeStop(e);
          this._fireEvent([clickedLayer], e);
        }
      }
    });
    /* */

    //@ts-ignore
    return L.vectorGrid.protobuf(nutsUrl, options);
  }



}
