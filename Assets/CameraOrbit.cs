using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraOrbit : MonoBehaviour
{
    private void Update()
    {
        var hoz = Input.GetAxis("Horizontal");
        var vrt = Input.GetAxis("Vertical");
        var look_hoz = Input.GetAxis("Mouse X");
        var look_vrt = Input.GetAxis("Mouse Y");

        var t = transform;
        var pos = t.position;

        var fwd = t.forward;
        var rgt = t.right;
        fwd = Quaternion.AngleAxis(-look_vrt * 20.0f, rgt) * fwd;
        var up = Vector3.Cross(rgt, fwd);
        fwd = Quaternion.AngleAxis(-look_hoz * 20.0f, up) * fwd;
        t.rotation = Quaternion.LookRotation(fwd, Vector3.up);
        

        pos += t.right * (hoz * Time.deltaTime * 300.0f);
        pos += t.forward * (vrt * Time.deltaTime * 300.0f);
        
        t.position = pos;
    }
}
