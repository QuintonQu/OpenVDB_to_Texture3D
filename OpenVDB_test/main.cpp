//
//  main.cpp
//  OpenVDB_test
//
//  Created by Ziyuan Qu on 2023/7/7.
//

#include <openvdb/openvdb.h>
#import <Foundation/Foundation.h>

#include <iostream>
#include <algorithm>

int main(int argc, const char * argv[]) {
    openvdb::initialize();
    
    // Open file
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"bunny_cloud" ofType:@"vdb"];
//    openvdb::io::File file([path UTF8String]);
    openvdb::io::File file("/Users/quinton/Documents/OpenVDB_to_Texture3D/model/bunny_cloud.vdb");
    file.open();
    
    openvdb::GridBase::Ptr base_grid;
    std::string gridname = "";
    
    for (openvdb::io::File::NameIterator name_iter = file.beginName();
        name_iter != file.endName(); ++name_iter)
    {
        // Read in only the grid we are interested in.
        if (gridname == "" || name_iter.gridName() == gridname) {
            std::cout << "reading grid " << name_iter.gridName() << std::endl;
            base_grid = file.readGrid(name_iter.gridName());
            if (gridname == "")
                break;
        } else {
            std::cout << "skipping grid " << name_iter.gridName() << std::endl;
        }
    }
    openvdb::FloatGrid::Ptr grid = openvdb::gridPtrCast<openvdb::FloatGrid>(base_grid);
    
    auto bbox = grid->evalActiveVoxelBoundingBox();

//    openvdb::tools::GridSampler<openvdb::FloatGrid, openvdb::tools::BoxSampler> sampler(*grid);
    
    openvdb::FloatGrid::Accessor accessor = grid->getAccessor();
    // Compute the value of the grid at fractional coordinates in index space.

    std::vector<float> values;
    std::vector<float> albedos;
    for (int k = bbox.min().z(); k < bbox.max().z(); ++k) {
        for (int j = bbox.min().y(); j < bbox.max().y(); ++j) {
            for (int i = bbox.min().x(); i < bbox.max().x(); ++i) {
                float value = accessor.getValue(openvdb::Coord(i, j, k));
                values.push_back(value);
                albedos.push_back(float((k - bbox.min().z()))/(bbox.max().z()-bbox.min().z()) / 2 + 0.5);
                albedos.push_back(float((j - bbox.min().y()))/(bbox.max().y()-bbox.min().y()));
                albedos.push_back(float((i - bbox.min().x()))/(bbox.max().x()-bbox.min().x()) / 2 + 0.5);
                // albedos.push_back(float(0));
                // albedos.push_back(float(0));
            }
        }
    }
    std::cout << *std::max_element(values.begin(),values.end()) << std::endl;
    std::cout << *std::max_element(albedos.begin(),albedos.end()) << std::endl;
    std::cout << *std::min_element(albedos.begin(),albedos.end()) << std::endl;
    
    return 0;
}
